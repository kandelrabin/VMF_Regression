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

## read in labels recorded by compass and wether they relate to bbc or not
streamLabels <- read.csv("D:\\Projects\\VMF_Regression\\ALL_STREAM_LABELS.csv", header = TRUE)

#### bring in data from sqlite database
dbPath <- ("D:\\Projects\\CMMData.db")
con <- dbConnect(RSQLite::SQLite(), dbname=dbPath)
vfm1 <- collect(tbl(con, 'panellstsVMF'))
temp <- tbl(con, 'audienceData12Weeks_incWeb')
audience<- collect(filter(temp, WEEK <= 8,
                          WEEK >= 5))
audienceWeight <- collect(filter(tbl(con, 'panelistsAll12WeeksWEIGHT'), 
                          WEEK <= 8,
                          WEEK >= 5))
dbDisconnect(con)

#### average the weight attributed to individuals
weightValue<- audienceWeight %>% 
  filter(startsWith(audienceWeight$INDIVIDUAL_ID, 'I') |startsWith(audienceWeight$INDIVIDUAL_ID, 'H') )%>% 
  mutate(ID = substr(INDIVIDUAL_ID, 3,11)) %>% 
  select(ID,WEIGHT) %>% 
  group_by(ID) %>% 
  summarise(avgWeight = mean(WEIGHT)) %>%
  distinct()
  
## remove leading I or H on ID
audienceBBC<- audience %>% 
  filter(startsWith(audience$INDIVIDUAL_ID, 'I') |startsWith(audience$INDIVIDUAL_ID, 'H') )%>% 
  mutate(ID = substr(INDIVIDUAL_ID, 3,11)) %>% 
  select(-INDIVIDUAL_ID) %>%
  distinct()

vfmAll <- vfm1 %>%mutate(ID = substr(INDIVIDUAL_ID, 3,11)) %>% 
  select(-INDIVIDUAL_ID, -SKY_VMF, -VIRGIN_VMF) %>%
  distinct()

## only select people in the metadata
audienceBBC <- inner_join(vfmAll %>%select(ID),audienceBBC,  by = 'ID' )

## label each even with the data type e.g BBC_RADIO
audienceBBC_labelled<- inner_join(audienceBBC, streamLabels, by = c('STREAM_LABEL' = 'STREAM_LABEL', 'DATA_TYPE'='DATA_TYPE') )

now()
#numDays<- audienceBBC %>%
       #group_by(ID) %>%
       #summarise(numDays = length(unique(as.Date(ymd_hms(audienceBBC$START))) ) )
now()

## get the average daily number of minutes per data type per person
bbcSplit<- audienceBBC_labelled %>%
  group_by(ID, WEEK,TYPE) %>%
  summarise(weeklyTimeSpent_sec = sum(as.numeric(hms(DURATION)))) %>%
  group_by(ID,TYPE)%>%
  summarise(dailyTimeSpent_min = mean(weeklyTimeSpent_sec)/(7*60))

bbcSplit$dailyTimeSpent_min[bbcSplit$dailyTimeSpent_min > 1440]<- 1440.0 #floor anything above 24 hours of time

bbcSplit<- bbcSplit %>%
  spread(TYPE, dailyTimeSpent_min) %>%
  mutate_all(~replace(., is.na(.), 0)) %>%
  mutate(total_hrs =  (BBC_OD_RADIO
         +BBC_OD_TV
         +BBC_RADIO
         +BBC_TV
         +BBC_WEB
         +NOT_MARKET_WEB
         +OTHER_OD_TV
         +OTHER_OD_AUDIO
         +OTHER_RADIO
         +OTHER_TV
         +OTHER_WEB)/60)


## join with metadata and weight
BBC_VFM<- inner_join(vfmAll, bbcSplit, by = 'ID') %>% select(4,1,2,3,5,6,7,8,9,10,11,12,13,14,15,16)
BBC_VFM<- inner_join(weightValue, BBC_VFM, by = 'ID')

## add age groupings
BBC_VFM_AGEBANDS <- BBC_VFM %>% 
  mutate(AGEGROUP = factor(cut(AGERAW, breaks = c(16,24,34,44,54,64,100), 
                               labels = c("16-24", "25-34","35-44","45-54", "55-64", "65+"))))%>%
  select(1,2,18,4,5,6,7,8,9,10,11,12,13,14,15,16,17) %>%
  distinct()
  
write.csv(BBC_VFM_AGEBANDS, "D:\\Projects\\VMF_Regression\\data\\BBC_VFM.csv",row.names = FALSE)
summary(BBC_VFM_AGEBANDS)


### Trim data

# temp<-BBC_VFM_AGEBANDS %>% gather(key = "TYPE", value = "dailyTimeSpent_min",
#                              BBC_OD_TV,
#                              BBC_RADIO,
#                              BBC_TV,
#                              BBC_WEB,
#                              NOT_MARKET_WEB,
#                              OTHER_OD_TV,
#                              OTHER_OD_AUDIO,
#                              OTHER_RADIO,
#                              OTHER_TV,
#                              OTHER_WEB,
#                              BBC_OD_RADIO)

#### plots #####
ggplot(data = BBC_VFM_AGEBANDS, mapping = aes(x = BBC_TV)) +
  geom_histogram(binwidth = 10)#+
  #scale_y_continuous(limits = c(0,10))

ggplot(data = temp, aes(y = dailyTimeSpent_min, x = TYPE))+
  geom_boxplot()+
  facet_wrap(~ TYPE, nrow = 1, scales = "free" )


### trim the data to set anything above the 95th percentile to the 95th percentile value ###
BBC_VFM_AGEBANDS<- as.data.frame(BBC_VFM_AGEBANDS)

trimData <- function(x){
  topLimit <- quantile( x, c(0.95 ))
  print(topLimit)
  x[ x < topLimit ] <- topLimit
}
for(col in 6:ncol(BBC_VFM_AGEBANDS)){trimData(BBC_VFM_AGEBANDS[,col])}

normalize(BBC_VFM_AGEBANDS, method = "standardize")

##############   Regression ########
fit1 <- lm(BBC_VMF ~ 
            AGEGROUP
          + GENDER
          + BBC_OD_RADIO
          + BBC_OD_TV
          + BBC_RADIO
          + BBC_TV
          + BBC_WEB
          + NOT_MARKET_WEB
          + OTHER_OD_TV
          + OTHER_OD_AUDIO
          + OTHER_RADIO
          + OTHER_TV
          + OTHER_WEB
          ,
          data = BBC_VFM_AGEBANDS,
          weights = avgWeight)

summary(fit1) # show results

fit2 <- lm(BBC_VMF ~ 
             AGEGROUP
           + GENDER
           # + BBC_OD_RADIO
           # + BBC_OD_TV
           + BBC_RADIO
           + BBC_TV
           + BBC_WEB
           # + NOT_MARKET_WEB
           # + OTHER_OD_TV
           # + OTHER_OD_AUDIO
           # + OTHER_RADIO
           # + OTHER_TV
           # + OTHER_WEB
           ,
           data = BBC_VFM_AGEBANDS)

summary(fit) # show results
anova(fit1,fit1)