library(tidyverse)
library(DBI)
library(dbplyr)
library("RSQLite")
library(knitr)
library(gridExtra)
library(grid)
library(ggplot2)
library(reshape2)
library(lubridate)
library(readr)
library(tidyr)
library(stringr)
library(data.table)
library(ggpmisc)

## read in people and which cluster they were assigned to.
cluster <- read.csv("D:\\Projects\\VMF_Regression\\data\\numPlatformClusteredGroups.csv", header = TRUE)
cluster <-  cluster %>% distinct()

### bring in panelists data conversions from Nation = 1 to Nation = England
panelistsCodes <- read.csv("D:\\Projects\\compassData\\panelistsCodes.csv", header = TRUE) %>%
  select(-QUESTION)
panelistsCodes$CODE<- as.integer(as.character(panelistsCodes$CODE))



#### bring in panelists data from sqlite database
dbPath <- ("D:\\Projects\\CMMData.db")
con <- dbConnect(RSQLite::SQLite(), dbname=dbPath)
temp <- tbl(con, 'audienceData12Weeks_incWeb')
audience<- collect(filter(temp, WEEK <= 8,
                          WEEK >= 5))
panelistsComplete <- collect(tbl(con, 'panelistsComplete')) %>% 
  filter(WEEK <= 8,WEEK >= 5)%>%
  select( INDIVIDUAL_ID,
          WEIGHT,
          AGERAW,
          GENDER,
          NATION,
          REGION,
          BBC_REGIONS,
          ITV_REGIONS,
          GOR_REGIONS,
          WORKING_STATUS,
          SOCIAL_GRADE,
          TV_RECEPTION_MAIN_TV,
          TV_RECEPTION_OTHER_TV,
          PVR_MAIN_TV,
          ACCESS_TO_TV_SERVICES,
          USAGE_OF_TV_SERVICES,
          ONLINE_ACCOUNT,
          IMPRESSION_BBC,
          IMPRESSION_ITV,
          IMPRESSION_CHANNEL_4,
          IMPRESSION_CHANNEL_5,
          IMPRESSION_SKY,
          BBC_VFM,
          SKY_VFM,
          VIRGIN_VFM,
          SOCIAL_GRADE_2, 
          RELIGION, 
          SEXUAL_ORIENTATION, 
          MARITAL_STATUS, 
          USAGE_OF_TV_SERVICES,
          ETHNICITY)
panelistsComplete<- panelistsComplete%>%
  filter(startsWith(panelistsComplete$INDIVIDUAL_ID, 'I') |startsWith(panelistsComplete$INDIVIDUAL_ID, 'H') )%>% 
  mutate(ID = substr(INDIVIDUAL_ID, 3,11)) %>%
  group_by(ID)%>%
  mutate(AGE = round(mean(AGERAW),1)) %>%
  select(-INDIVIDUAL_ID, - WEIGHT, -AGERAW)%>% 
  distinct()

audienceWeight <- collect(filter(tbl(con, 'panelistsAll12WeeksWEIGHT'), 
                                 WEEK <= 8,
                                 WEEK >= 5)) 
audienceWeight<- audienceWeight %>%
  filter(startsWith(audienceWeight$INDIVIDUAL_ID, 'I') |startsWith(audienceWeight$INDIVIDUAL_ID, 'H') )%>% 
  mutate(ID = substr(INDIVIDUAL_ID, 3,11))%>%
  select(-INDIVIDUAL_ID)
dbDisconnect(con)

#panellistColNames <- t(t(colnames(panelistsComplete)))
metadata<- inner_join(cluster %>% select(ID, cluster),
                       panelistsComplete %>% 
                        select(ID, AGE, GENDER, NATION, REGION, WORKING_STATUS, SOCIAL_GRADE, RELIGION, SEXUAL_ORIENTATION, ETHNICITY,
                               IMPRESSION_BBC, IMPRESSION_ITV, IMPRESSION_CHANNEL_4, IMPRESSION_CHANNEL_5,
                               BBC_VFM, SKY_VFM, VIRGIN_VFM),
                       by = "ID") %>%distinct()


metadataColNames <- t(t(colnames(metadata))) ##create a list of the column names in metadata
## loop across the columns, join with the relavent part of the code df and replace the code with the names.
for(x in 4:ncol(metadata)){
  print(colnames(metadata)[4])
  colnames(metadata)[4]<- "CODE"
  
  metadata<- left_join(metadata, 
            panelistsCodes %>% 
              filter(PANELLIST_FILE_NAME == metadataColNames[x]) %>% 
              select(-PANELLIST_FILE_NAME),
            by = "CODE")
  
  
  colnames(metadata)[ncol(metadata)]<- metadataColNames[x]
  metadata <- metadata %>% select(-CODE)
}
metadata$IMPRESSION_BBC <- as.integer(as.character(metadata$IMPRESSION_BBC))
metadata$IMPRESSION_ITV <- as.integer(as.character(metadata$IMPRESSION_ITV))
metadata$IMPRESSION_CHANNEL_4 <- as.integer(as.character(metadata$IMPRESSION_CHANNEL_4))
metadata$IMPRESSION_CHANNEL_5 <- as.integer(as.character(metadata$IMPRESSION_CHANNEL_5))
metadata$BBC_VFM<- as.integer(as.character(metadata$BBC_VFM) )
metadata$SKY_VFM<- as.integer(as.character(metadata$SKY_VFM) )
metadata$VIRGIN_VFM<- as.integer(as.character(metadata$VIRGIN_VFM) )

head(metadata)


### compare the high VFM ranking cluster with the low one on their opinions of other channels.
tvOpinions_highVFMcluster <- metadata %>% 
  filter(cluster == 3) %>% 
  select(ID, 
         IMPRESSION_BBC, 
         IMPRESSION_ITV, 
         IMPRESSION_CHANNEL_4, 
         IMPRESSION_CHANNEL_5, 
         BBC_VFM, 
         SKY_VFM, 
         VIRGIN_VFM) %>% distinct()
tvOpinions_lowVFMcluster <- metadata %>% 
  filter(cluster == 4) %>% 
  select(ID, 
         IMPRESSION_BBC, 
         IMPRESSION_ITV, 
         IMPRESSION_CHANNEL_4, 
         IMPRESSION_CHANNEL_5, 
         BBC_VFM, 
         SKY_VFM, 
         VIRGIN_VFM)%>% distinct()


write.csv(tvOpinions_highVFMcluster, "D:\\Projects\\VMF_Regression\\data\\ClusterAnalysis\\tvOpinions_highVFMcluster.csv", row.names = FALSE)
summary(tvOpinions_highVFMcluster)
summary(tvOpinions_lowVFMcluster)


############################### Compare the groups on their metadata ############################
meta_highVFMcluster <- metadata %>% 
  filter(cluster == 3) %>% 
  select(ID, 
         AGE,
         NATION,
         REGION,
         WORKING_STATUS,
         SOCIAL_GRADE,
         RELIGION,
         SEXUAL_ORIENTATION,
         ETHNICITY
         ) %>% distinct() 

meta_lowVFMcluster <- metadata %>% 
  filter(cluster == 4) %>% 
  select(ID, 
         AGE,
         NATION,
         REGION,
         WORKING_STATUS,
         SOCIAL_GRADE,
         RELIGION,
         SEXUAL_ORIENTATION,
         ETHNICITY
  ) %>% distinct()

summary(meta_highVFMcluster)
summary(meta_lowVFMcluster)
write.csv(meta_lowVFMcluster, "D:\\Projects\\VMF_Regression\\data\\ClusterAnalysis\\meta_lowVFMcluster.csv", row.names = FALSE)


#### summarise meta data with proportions from each section
colNames <- t(t(colnames(meta_highVFMcluster))) ##create a list of the column names

### for high VFM group
metaSummary_highVFMcluster<- data.frame()
for(col in 3:ncol(meta_highVFMcluster)){
  temp<- meta_highVFMcluster %>% 
    group_by_at(col) %>%
    summarise(perc = round(100*length(unique(ID))/964,1)) %>%
    mutate(category = as.character(colNames[col]))
  colnames(temp)[1]<- "subcategory"
  
  temp<- temp %>% select(3,1,2)
  
  metaSummary_highVFMcluster<- rbind(metaSummary_highVFMcluster, temp)
}

write.csv(metaSummary_highVFMcluster, "D:\\Projects\\VMF_Regression\\data\\ClusterAnalysis\\metaSummary_highVFMcluster.csv", row.names = FALSE)

### for low vfm group
colNames <- t(t(colnames(meta_lowVFMcluster))) ##create a list of the column names
metaSummary_lowVFMcluster<- data.frame()

for(col in 3:ncol(meta_lowVFMcluster)){
  temp<- meta_lowVFMcluster %>% 
    group_by_at(col) %>%
    summarise(perc = round(100*length(unique(ID))/852,1)) %>%
    mutate(category = as.character(colNames[col]))
  colnames(temp)[1]<- "subcategory"
  
  temp<- temp %>% select(3,1,2)
  
  metaSummary_lowVFMcluster<- rbind(metaSummary_lowVFMcluster, temp)
}

write.csv(metaSummary_lowVFMcluster, "D:\\Projects\\VMF_Regression\\data\\ClusterAnalysis\\metaSummary_lowVFMcluster.csv", row.names = FALSE)

 ######################   Gender Age ##############################

summary(metadata %>% ### low group
           filter(cluster == 4) %>% 
           select(ID, 
                  AGE,
                  GENDER
           ) %>% distinct()
)

summary(metadata %>% ### high group
          filter(cluster == 3) %>% 
          select(ID, 
                 AGE,
                 GENDER
          ) %>% distinct()
)

########### Which Platforms? ##########
## read in labels that are split into platforms

platform <- read.csv("D:\\Projects\\VMF_Regression\\PLATFORMS.csv", header = TRUE)

## remove leading I or H on ID
audienceBBC<- audience %>% 
  filter(startsWith(audience$INDIVIDUAL_ID, 'I') |startsWith(audience$INDIVIDUAL_ID, 'H') )%>% 
  mutate(ID = substr(INDIVIDUAL_ID, 3,11)) %>% 
  select(-INDIVIDUAL_ID) %>%
  distinct()


numWeeksAudience <- audienceBBC %>% 
  group_by(ID)%>% 
  summarise(numWeeksTotal = length(unique(as.character(WEEK))))

platformData<- inner_join(audienceBBC, platform, by = "STREAM_LABEL")

moreThan3Mins<- platformData %>% 
  group_by(ID, WEEK, PLATFORM, STREAM_LABEL) %>%
  summarise(totalDuration = sum(as.numeric(hms(DURATION)))) %>%
  filter(totalDuration > 180)

numPlatform<- moreThan3Mins %>% 
  select(ID, WEEK, PLATFORM)%>%
  distinct() %>%
  mutate(visit = 1) %>%
  group_by(ID, PLATFORM) %>%
  summarise(numVisits = sum(visit)) %>%
  right_join(numWeeksAudience,  by = "ID") %>%
  mutate(scaledNumVisits = numVisits / numWeeksTotal) %>%
  select(ID, PLATFORM, scaledNumVisits) #%>%
  #spread(key = PLATFORM, value = scaledNumVisits) %>%
  #mutate_all(~replace(., is.na(.), 0))
  

numPlatform_highVFM<- inner_join(numPlatform, metadata %>% filter(cluster == 3) %>% select(ID), by = "ID") %>% 
  group_by(PLATFORM)%>%
  summarise(avgPercentageVisiting_highVFM = round(100*sum(scaledNumVisits)/964,0))

numPlatform_lowVFM<- inner_join(numPlatform, metadata %>% filter(cluster == 4) %>% select(ID), by = "ID") %>% 
  group_by(PLATFORM)%>%
  summarise(avgPercentageVisiting_lowVFM = round(100*sum(scaledNumVisits)/852,0))

### On average the percentage of people which visited each platform for more than 3 minutes per visit in one week
platformComparison<- full_join(numPlatform_highVFM, numPlatform_lowVFM, by = "PLATFORM")
platformComparison

write.csv(platformComparison, "D:\\Projects\\VMF_Regression\\data\\ClusterAnalysis\\platformComparison.csv", row.names = FALSE)


##########  Time Spent with BBC #########

timeWithBBC_Total<- platformData[c(1:10),] %>% 
  group_by(ID, WEEK, PLATFORM, STREAM_LABEL) %>%
  mutate(touchDuration = sum(as.numeric(hms(DURATION)))) %>%
  group_by(ID,WEEK) %>%
  summarise(weeklyDuration = sum(as.numeric(hms(DURATION))) )%>% ## weekly duration per person
  inner_join(numWeeksAudience, by = "ID") %>% ## add in number of weeks in the sample /4
  group_by(ID)%>%
  summarise(avgWeeklyDuration = sum(weeklyDuration)/numWeeksTotal) %>% ## find average weekly duration
  inner_join(metadata %>%select (ID, cluster), by = "ID" ) %>% ## add in cluster
  distinct()%>%
  group_by(cluster)%>%
  summarise(avgWeeklyDurationPP_min = sum(avgWeeklyDuration)/(60* length(ID)),
            numInCluster = length(ID))## average weekly duration for the cluster


## find the total weight of each cluser based on the average weight of each participant
clusterWeight<- left_join(cluster %>% select(ID, cluster),
                          audienceWeight %>%select(ID, WEIGHT) %>%
                            group_by(ID)%>%
                            summarise(avgWeight = mean(WEIGHT)), by = "ID" ) %>%
  group_by(cluster)%>%
  summarise(clusterWeight = sum(avgWeight))

platformData<- platformData %>% arrange(ID)
platformData %>% 
  group_by(ID, WEEK) %>%
  summarise(weeklyDuration = sum(as.numeric(hms(DURATION))))%>% ## get total duration in a week
  inner_join(audienceWeight, by = c("ID", "WEEK")) %>%
  mutate(weeklyDurWeighted = weeklyDuration*WEIGHT)%>% #multiply by person's weight that week
  inner_join(numWeeksAudience, by = "ID") %>%
  group_by(ID)%>%
  mutate(avgWeeklyDurWeighted_min = sum(weeklyDurWeighted)/(60*numWeeksTotal))%>% # find their weekly weighted average
  select(ID, avgWeeklyDurWeighted_min)%>%
  distinct()%>%
  inner_join(metadata %>%select (ID, cluster), by = "ID" ) %>%
  group_by(cluster) %>%
  summarise(clusterTotalTime_min = sum(avgWeeklyDurWeighted_min))%>% # find total time for cluster
  inner_join(clusterWeight, by = "cluster") %>%
  group_by(cluster)%>%
  summarise(weeklyDurPerPerson_hours = clusterTotalTime_min/(60*clusterWeight))## average time in a week per person in the cluster
  


