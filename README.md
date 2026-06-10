# Final Paper – Digital Korea

## Sentiment and Topics in Korean Colonial Magazines (1896–1942)

**Course:** BA2 Digital Korea
**Student:** Femke Slegers
**University:** Leiden University
**Year:** 2026

---

## Project Description

This repository contains the materials for a replication of the final paper "Sentiment and Topics in Korean Colonial Magazines (1896–1942)."

The project analyzes how the tone and themes of Korean magazines changed throughout different periods of Japanese colonial rule. Computational text analysis methods were applied to a corpus of Korean magazines to find patterns that would be difficult to detect through reading alone.

The analysis combines dictionary-based sentiment analysis with Latent Dirichlet Allocation (LDA) topic modeling.

---

## Research Question

**How did the multiple topics and sentiment of Korean colonial magazines change across different periods of Japanese colonial rule between the pre-colonial period and 1945?**

---

## Headline Findings

The results suggest that both the emotional tone and thematic content of Korean magazines changed throughout the colonial period.

* The **pre-colonial period** contains diverse topics relating to education, politics, family life, and modernization.
* The **start of the colonial period** shifts towards education and economic concerns while political topics are not as important.
* During **relative liberalization**, themes of culture, religion, and national identity become more visible.
* The **harsh conservative government** period focuses more strongly on rural society, education, and economic issues.
* The **militarization and ethnocide** period combines discussions of everyday life with themes related to Japan, imperial ideology, and education.

Sentiment analysis further indicates that emotional language varied across historical periods, with the final period showing the greatest diversity of sentiment scores.

---

## Repository Structure

```text

├── data/
│   ├── colonial_magazines_sample.csv
│   ├── positive.txt
│   ├── negative.txt
│   └── stopwords_ko.txt
│
├── output/
│   ├── topic_summary_by_era.csv
│   └── sentiment_scores_by_era.png
│
├── figures/
│   ├── topic_summary_by_era.csv
│   └── sentiment_scores_by_era.png
│
├── Final_Paper.pdf
├── README.md
├── LICENSE
├── CITATION.cff
└── RStudio dataset.R
```

---

## Data

The analysis uses the colonial_magazines_sample corpus, consisting of Korean magazines published between 1896 and 1942.

The corpus was divided into five historical periods:

| Period                        | Years     |
| ----------------------------- | --------- |
| Pre-colonial                  | 1896–1909 |
| Start of colonial period      | 1910–1918 |
| Relative liberalization       | 1919–1924 |
| Harsh conservative government | 1925–1931 |
| Militarization and ethnocide  | 1932–1942 |

---

## Acknowledgement

This project was completed as part of the **BA2 Digital Korea** course at **Leiden University**.

The corpus and preprocessing resources were provided through the course materials and adapted for this analysis.
