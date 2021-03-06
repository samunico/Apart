# Title: Sentiment Analysis of 30th Dail
# Context: APART
# Author: J. Areal, P. Mendoza
# Date: Fri Oct 04 12:06:30 2019
# Dataset used: Herzog, Alexander; Mikhaylov, Slava, 2017, "Dail_debates_1919-2013.tar.gz", Database of Parliamentary Speeches in Ireland, 1919-2013, https://doi.org/10.7910/DVN/6MZN76/CRUNF0, Harvard Dataverse, V2
# 0. Content ------------------------------------------------------------
#  1. Preparation
#  2. Corpus Preparation
#  3. Entity Detection
#
#
#
# 1. Preparation --------------------------------------------------------
# __Loading Packages -------------------------------------------------
rm(list=ls())
usePackage <- function(p) {if (!is.element(p, installed.packages()[,1]))install.packages(p,dep = TRUE, repos = "http://cran.wu.ac.at"); library(p, character.only = TRUE)}
pkgs <- c('beepr', 'tidyverse', 'rio', 'tidylog', 'skimr',
          'quanteda', 'readtext', 'Hmisc',
          'googledrive', 'readtext', 'data.table', 'stringr', 'qdap'); for (i in pkgs){usePackage(i)}


# __Loading Data -----------------------------------------------------
# Download again vs. subsample file already existing?
# Get Data from: 
    # 1) Website (original) 
    # 2) Drive (subset) 
    # 3) local (subset)
downl <- 3

if (downl == 1){
# These lines downlad the original data from the website; unpack them; and read them into the program
# Following line not yet working, somehow I can unpack the manually downloaded file, but not the one downloaded via R
download.file(url="https://dataverse.harvard.edu/api/access/datafile/:persistentId?persistentId=doi:10.7910/DVN/6MZN76/CRUNF0",
              destfile = "Dail_debates_1919-2013.tar.gz") # https://stat.ethz.ch/R-manual/R-devel/library/utils/html/download.file.html
# unpacking the file
untar(tarfile = "Dail_debates_1919-2013.tar.gz")

## Read file 
df <- fread("Dail_debates_1919-2013.tab", sep="\t", 
            quote="", header=TRUE, showProgress = TRUE, data.table=FALSE, verbose = TRUE)

## Subsetting
# Take only the ones of the latest 2 legislative periods
# latest recorded speech: 2013-03-28
# Adding legislative period variable:
df$datef <- as.Date(df$date) # making sure that date variable is in date format
per <- import("DailPeriods.csv")
per$end[per$dail==max(per$dail)] <- Sys.Date() %>% as.character()
for (i in 1:nrow(per)){df$legper[(df$datef >= per$begin[i] & df$datef <= per$end[i])] <- per$dail[i]}
dfs <- df %>% filter(legper >= 30); beep(2)
# dfs$datef %>% min # double checking: ✓ 
export(dfs, "dail_subset.Rdata")
export(dfs, "dail_subset.csv")
drive_upload(media="dail_subset.csv", 
             path="~/Internship AffPol in Text/Data/Ireland/dail_subset.csv")
} else if (downl==2) {
  drive_download(file = "~/Internship AffPol in Text/Data/Ireland/dail_subset.csv")
  dfs <- readtext("dail_subset.csv", text_field = "speech")
} else if (downl==3) {
  dfs <- readtext("dail_subset.csv", text_field = "speech")
}

# 2. Corpus preparation ----------------------------------------------------------
df_30th_dail <- dfs[dfs$legper==30,] #only 30th legislature
corpus_30th_dail <- corpus(df_30th_dail)

## Tokenize corpus, and remove stop punctuation and stopwords
tokens_30th_dail <- tokens(corpus_30th_dail, remove_punct = T)
tokens_30th_dail <- tokens_select(tokens_30th_dail, stopwords('english'), selection='remove')


# 3. Entity Detection --------------------

## update data
fn <- "https://drive.google.com/open?id=1vcR0GAE-nxjJo8AqJp-raP6B8hSthEdl"
drive_get(fn)
drive_download(file = fn, overwrite = T)

## Cleaning dictionary
entities_30th_dail <- read.csv("entities_30th_dail.csv", row.names =1,stringsAsFactors = F)
entities_30th_dail <- c(entities_30th_dail$match, entities_30th_dail$alternativematch)
entities_30th_dail <- entities_30th_dail[!is.na(entities_30th_dail)]


#entities_30th_dail <- rm_stopwords(entities_30th_dail, Top25Words, separate = F, strip=T) # remove stop words and punctuation
#entities_30th_dail <- tools::toTitleCase(entities_30th_dail) # capitalise all words
#entities_30th_dail <- gsub("(O'.)","\\U\\1",entities_30th_dail,perl=TRUE) # capitalise names starting with O'

## Creating windows (match of entities)
kwic_30th_dail <- kwic(tokens_30th_dail, pattern=phrase(entities_30th_dail), window=20, case_insensitive = F)



# Analyses ----------------------------------------------------------

## Create df_window where 1 row = 1 window preserving original docvars
df_window_30th_dail <- merge(df_30th_dail, kwic_30th_dail, by.y="docname", by.x="doc_id")
df_window_30th_dail$window <- paste(df_window_30th_dail$pre, df_window_30th_dail$keyword, df_window_30th_dail$post, sep=" ")


## Sentiment analysis of windows
corpus_window_30th_dail<- corpus(df_window_30th_dail, text_field = 'window') #first transform df to corpus
sentanalysis_30th_dail <- dfm(corpus_window_30th_dail, dictionary=data_dictionary_LSD2015[1:2]) #sentiment analysis
df_window_30th_dail <- cbind(df_window_30th_dail, convert(sentanalysis_30th_dail, to="data.frame")) # add sentiment analysis to df_window


## Sentiment score = (positive words - negative words)/total tokens in that window
df_window_30th_dail$ntoken_window <- ntoken(df_window_30th_dail$window) # number of tokens per window
df_window_30th_dail$sentiment_score <- (df_window_30th_dail$positive - df_window_30th_dail$negative)/df_window_30th_dail$ntoken_window
df_window_30th_dail$log_sentiment_score <- log((df_window_30th_dail$positive + 0.5)/(df_window_30th_dail$negative + 0.5))

# Now 1 row = 1 window, with docvars + sentiment score


## Write df_window to .csv and upload it to Drive

write.csv(df_window_30th_dail, "df_window_30th_dail.csv")
drive_upload("df_window_30th_dail.csv",
             path="~/Internship AffPol in Text/Data/Ireland/",
             overwrite = T)
