
##the various libraries to use for this script
library(tidyverse)
library(tidytext)
library(reticulate)
library(ggplot2)
library(topicmodels)
library(reshape2)


##preprocessing script
if (packageVersion("reticulate") >= "1.40") {
     py_require(c("kiwipiepy", "hanja"))      # declares both dependencies
} else {
   tryCatch(install_miniconda(), error = function(e)
       message("Miniconda already installed or not needed — continuing."))
   py_install(c("kiwipiepy", "hanja"), pip = TRUE)
}
 
cat("kiwipiepy:", py_module_available("kiwipiepy"),
   " hanja:", py_module_available("hanja"), "\n")





## change this to the location of you corpus
corpus <- read_csv("data/colonial_magazines_sample", show_col_types = FALSE)
s <- spec(corpus)

cat("Loaded", nrow(corpus), "articles\n")


## change this to the location of your stopword file
stopword_file <- normalizePath(
   "data/stopwords_ko.txt",
   winslash = "/",
   mustWork = TRUE
)

TEXT_COLUMN      <- "text" 
HANMUN_THRESHOLD <- 0.60



py_run_string(sprintf("
from kiwipiepy import Kiwi
import hanja
kiwi = Kiwi()
 
stopwords = set()
try:
   with open('%s', encoding='utf-8') as f:
       for line in f:
           w = line.strip()
           if w and ' ' not in w:
               stopwords.add(w)
               if len(w) > 1 and w.endswith('다'):
                   stopwords.add(w[:-1])
except FileNotFoundError:
   pass

# Classical-Chinese function words to drop in the Hanmun branch.
hanmun_stopwords = set('之 而 不 則 其 也 矣 乎 焉 者 以 於 于 所 乃 且 亦 即 既 故 哉 耳 歟 耶 邪 兮 諸 斯 蓋 凡 惟 唯'.split())

def _is_hanja(c):
   o = ord(c)
   return (0x3400 <= o <= 0x9fff) or (0xf900 <= o <= 0xfaff) or (0x20000 <= o <= 0x2fa1f)

def _is_hangul(c):
   return 0xac00 <= ord(c) <= 0xd7a3
 
def hanja_ratio(text):
   if not text or not isinstance(text, str):
       return 0.0
   h = sum(1 for c in text if _is_hanja(c))
   k = sum(1 for c in text if _is_hangul(c))
   return h / (h + k) if (h + k) else 0.0

def preprocess(text, pos_tags, hanmun_threshold):
   if not text or not isinstance(text, str):
       return []
   # HANMUN branch: Classical Chinese -> 1 Hanja = 1 token, drop particles
   if hanja_ratio(text) >= hanmun_threshold:
       return [c for c in text if _is_hanja(c) and c not in hanmun_stopwords]
   # KOREAN branch: Hanja -> reading, safety-strip residue, Kiwi nouns
   text = hanja.translate(text, 'substitution')
   text = ''.join(' ' if _is_hanja(c) else c for c in text)
   out = []
   for t in kiwi.tokenize(text):
       if t.tag.split('-')[0] in pos_tags and len(t.form) >= 2 and t.form not in stopwords:
           out.append(t.form)
   return out
", stopword_file))
 
cat("Kiwi + hanja ready\n")

pos_tags <- c("NNG", "NNP")
 
corpus <- corpus |>
    mutate(
       hanja_ratio    = map_dbl(.data[[TEXT_COLUMN]], ~ py$hanja_ratio(.x)),
       text_type      = if_else(hanja_ratio >= HANMUN_THRESHOLD, "hanmun", "korean"),
       tokens         = map(.data[[TEXT_COLUMN]],
                            ~ py$preprocess(.x, pos_tags, HANMUN_THRESHOLD)                           
                            .progress = "Tokenizing"),
       processed_text = map_chr(tokens, ~ paste(.x, collapse = " "))
     )

cat("text_type counts:\n")

print(count(corpus, text_type))


corpus_korean <- corpus |> filter(text_type == "korean")
corpus_hanmun <- corpus |> filter(text_type == "hanmun")
 
cat("\nExample KOREAN article (readings + nouns):\n")


## change this to the location of your sentiment lexicons
negative_words <- readLines(
  "data/negative.txt",
  encoding = "UTF-8"
)

positive_words <- readLines(
  "data/positive.txt",
  encoding = "UTF-8"
)

my_sentiments <- tibble(
  word = c(positive_words, negative_words),
  sentiment = c(
    rep("positive", length(positive_words)),
    rep("negative", length(negative_words))
  )
)


##sentiment by era
corpus_korean_by_era <- corpus_korean %>%
  mutate(
    era = case_when(
      year < 1910 ~ "pre-colonial",
      year >= 1910 & year < 1919 ~ "start of colonial period",
      year >= 1919 & year < 1925 ~ "relative liberalization",
      year >= 1925 & year < 1932 ~ "harsh conservative government",
      year >= 1932 & year <= 1945 ~ "militarization, ethnocide",
      TRUE ~ NA_character_
    ),
    era = factor(
      era,
      levels = c(
        "pre-colonial",
        "start of colonial period",
        "relative liberalization",
        "harsh conservative government",
        "militarization, ethnocide"
      )
    )
  )

tokens <- corpus_korean_by_era %>%
  mutate(article_id = row_number()) %>%
  select(article_id, era, processed_text) %>%
  filter(!is.na(era), processed_text != "") %>%
  unnest_tokens(word, processed_text)

sentiment_by_article <- tokens %>%
  inner_join(my_sentiments, by = "word") %>%
  count(article_id, era, sentiment) %>%
  pivot_wider(
    names_from = sentiment,
    values_from = n,
    values_fill = 0
  ) %>%
  mutate(
    sentiment_score = positive - negative,
    total_sentiment_words = positive + negative,
    sentiment_percent = sentiment_score / total_sentiment_words * 100
  )

ggplot(sentiment_by_article,
       aes(x = era, y = sentiment_score, fill = era)) +
  geom_violin(trim = FALSE, alpha = 0.6) +
  geom_boxplot(width = 0.12, outlier.size = 0.5) +
  labs(
    title = "Distribution of Sentiment Scores by Era",
    x = "Era",
    y = "Sentiment Score"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 25, hjust = 1),
    legend.position = "none"
  )


##script for LDA topics
eras <- levels(corpus_korean_by_era$era)

lda_models <- map(eras, function(e){
  
  dtm <- corpus_korean_by_era %>%
    filter(era == e) %>%
    mutate(document = row_number()) %>%
    select(document, processed_text) %>%
    filter(processed_text != "") %>%
    unnest_tokens(word, processed_text) %>%
    count(document, word) %>%
    cast_dtm(document, word, n)
  
  LDA(dtm, k = 8, control = list(seed = 1234))
  
})

names(lda_models) <- eras

topic_words <- map_df(
  names(lda_models),
  function(e){
    
    tidy(lda_models[[e]], matrix = "beta") %>%
      group_by(topic) %>%
      slice_max(beta, n = 10) %>%
      ungroup() %>%
      mutate(era = e)
    
  }
)

topic_words




topic_summary <- topic_words %>%
  group_by(era, topic) %>%
  summarise(
    top_words = paste(term, collapse = ", "),
    .groups = "drop"
  )

topic_summary


## change this to your output location
write.csv(
  topic_summary,
  "output/topic_summary_by_era.csv",
  row.names = FALSE
)
