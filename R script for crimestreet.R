###############################################################################################
# This script is design to calculate the crimes per street for the philadelphia census tract###
###############################################################################################

## Fangnan Du##

# 1 preparation
# 1.1 environment set up
library(dplyr)
library(tidyverse)
library(sf)
library(lubridate)
library(caret)
library(pscl)
library(e1071)
library(RPostgreSQL)
library(sf)
library(postGIStools)
library(tidyverse)
library(viridis)
library(classInt)

mapTheme <- function(base_size = 12) {
  theme(
    text = element_text( color = "black"),
    plot.title = element_text(size = 30,colour = "black"),
    plot.subtitle=element_text(face="italic"),
    plot.caption=element_text(hjust=0),
    axis.ticks = element_blank(),
    panel.background = element_rect("darkgrey"),
    axis.title = element_blank(),
    axis.text = element_blank(),
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    panel.grid.major = element_line("darkgrey"),
    panel.grid.minor = element_line("darkgrey"),
    panel.border = element_rect(colour = "black", fill=NA, size=2)
  )
}

# 1.2 Connnect to the SQL 

drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = "musa620",
                 host = "127.0.0.1", port = 5432,
                 user = "postgres", password = 'a123456')



# 2 data cleanning and  wrangling

# 2.1 import the crime data 
crime<- read.csv("crime.csv")
head(crime)
# 2.2 specify the time period and the crime type
#the criteria for the crime selection
#selet the crime is happened in 2017 
#using the dms to sperate the time series
crime$Dispatch_Date_Time<-ymd_hms(crime$Dispatch_Date_Time)
crime$year<-year(crime$Dispatch_Date_Time)
crime$hour<-hour(crime$Dispatch_Date_Time)
#2.2.1 remove all the na from the crime
crime<-na.omit(crime)
#2.2.2 select the crime type belongs to 
crimeselected<- filter(crime, year == 2017 | year ==2016)
write.csv(crimeselected,'crime2.csv') # for later quicker read (avoid crush up)
# ps. selection for type for 'fraud', but it will induce the number below 10,000
#crimeselected<- filter(crimeselected,Text_General_Code == 'Fraud'  )
#write.csv(crimeselected,'crime3.csv')



# 3 load the geospatial information and write it to the Postgres
# 3.1 crime data transformation
# transform to the sf
crimeSF <- st_as_sf(crimeselected, coords = c("Lon", "Lat"), crs = 4326)
#set the projection
crimeSF <- st_transform(crimeSF, 3785)
# add to the database
st_write_db(con, crimeSF, "crimes",drop = TRUE)

# 3.2 import the philly census tract 
phillySF <- st_read('census-tracts-philly.shp', stringsAsFactors = FALSE)
# lower case the philly 'gisjoin' avoiding for crash
phillySF <- rename(phillySF, gisjoin = GISJOIN)
# set the projection (mercator)
phillySF <- st_transform(phillySF, 3785)
#write it to the Postgres
st_write_db(con, phillySF, "phillysf",drop = TRUE)
dbGetQuery(con, "SELECT * FROM geometry_columns")

#for checking the wkb_geometry
#phillySF = st_read_db(con, query = "SELECT * FROM phillysf", geom_column = 'wkb_geometry')
#dbGetQuery(con, "SELECT UpdateGeometrySRID('phillysf','wkb_geometry',3785)")


# 3.3 isolate the crimes in Philly

spatialQuery <- paste0("SELECT a.* ",
                       "FROM phillysf AS p, crimes AS a ",
                       "WHERE ST_Contains(p.wkb_geometry, a.wkb_geometry)")
crimesInPhilly <- st_read_db(con, query=spatialQuery, geom_column='wkb_geometry')
st_write_db(con, crimesInPhilly, "crimesinphilly", drop=TRUE)

# create the index for processing quicker( later spatialquery)
######
#This important, or it will take a very long time.
dbGetQuery(con, "CREATE INDEX crimesinphilly_gix ON crimesinphilly USING GIST (wkb_geometry)")
dbGetQuery(con, "CREATE INDEX crimes_gix ON crimes USING GIST (wkb_geometry)")


# 3.4 add Philly's road network
phillyStreets <- st_read('Street_Centerline.shp', stringsAsFactors = FALSE)
# set the projection
phillyStreets <- st_transform(phillyStreets, 3785)
#rename the seg_id
phillyStreets <- rename(phillyStreets,seg_id=SEG_ID)
#write to the Postgres
st_write_db(con, phillyStreets, "phillystreets",drop = TRUE)

### create the index for processing quicker( later spatialquery)
######
#This important, or it will take a very long time.
dbGetQuery(con, "CREATE INDEX phillystreets_gix ON phillystreets USING GIST (wkb_geometry)")


# 4 For each crime, find its nearest street (seg_id)

spatialQuery <- paste0("SELECT DISTINCT ON (a.wkb_geometry) a.*, p.seg_id, ",
                       "ST_Distance(a.wkb_geometry, p.wkb_geometry) AS distance ",
                       "FROM crimes AS a, phillystreets AS p ",
                       "WHERE ST_Distance(a.wkb_geometry, p.wkb_geometry) < 500 ", # ***** THIS IS THE IMPORTANT ONE
                       "ORDER BY a.wkb_geometry, ST_Distance(a.wkb_geometry, p.wkb_geometry) ASC")



#####################################################################
#     ?   Question 1 

#########################################
# for doing this spatialquery, i wonder how can i produce a progress bar for it 
# install.packages("progress")
# library(progress)
# pb <- progress_bar$new(total = 100)
# for (i in 1:100) {
#   pb$tick()
#   Sys.sleep(1 / 100)
# }
#Let's time it


####################
# ?  question 2 
#excute the query, the crimeswithnearestroad only has 2968 obs. but the crimsinphilly has 4466. where are the missing data?"
################################



# crimesWithNearestRoad2 <- st_read_db(con, query=spatialQuery, geom_column='wkb_geometry')
# crimesWithNearestRoad <- st_read_db(con, query=spatialQuery, geom_column='wkb_geometry')

# using the time calculator, i find it will takes almost 20 minutes although i have created the index and write the shaprefile into the Postgres

startTime <- Sys.time()
crimesWithNearestRoad3 <- st_read_db(con, query=spatialQuery, geom_column='wkb_geometry')
endTime <- Sys.time()
endTime - startTime

######################h
# ? question 3 
#how to directly excute the query to write the data#
##################
#st_write(crimesWithNearestRoad,"crimestreet.shp")
st_write(crimesWithNearestRoad3,"crimestreet3.shp")


# 5 for each street , count the crimes belongs to this specific street
# read the crime with street seg_id
crimestreetfinal <- st_read('crimestreet2.shp', stringsAsFactors = FALSE)
crimestreetfinal <- st_transform(crimestreetfinal, 3785)
st_write_db(con, crimestreetfinal, "cf2")

#st_write_db(con, crimesWithNearestRoad , "crimeswithnearestroad ",drop=TRUE)

sqlCommand1 <- paste0("SELECT s.seg_id,COUNT(c.*) AS num ",
                      "FROM cf2 AS c ",
                      "JOIN phillystreets AS s ",
                      "ON c.seg_id = s.seg_id ",
                      "GROUP BY s.seg_id ")

countnew<-dbGetQuery(con, sqlCommand1)

# adding the spatial info to the streets which have the count number of seg_id 
countnew<-merge(count,phillyStreets)

# 6 data visualization

pallete5_colors <- c('#66bd63','#ffffbf','#d73027')
# the discrete
Applydiscrete <- function(x) {
  cut(x, breaks = c (0.9,1.9,3.1,8.2), 
      labels=c("low crime ","medium crime","high crime")
  )
}

startTime <- Sys.time()
ggplot() +
  geom_sf(data = phillySF, fill="#bbbbbb", color = NA) +
  geom_sf( data = countnew, aes(color= Applydiscrete(countnew$num))) +
  scale_color_manual(values = c("green", "yellow", "red"))+
  labs(title = "Crime Frequency in Each Street",
       color = "Crime Level")+
  myTheme()

#Disconnect
endTime <- Sys.time()
endTime - startTime

dbDisconnect(con)
dbUnloadDriver(drv)

