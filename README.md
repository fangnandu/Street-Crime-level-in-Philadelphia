# Street-Crime-Level
Creating a map to visualize Crime level for each street in Philadelphia
In this project, I used the crimes, census tracts and street shapefile to create a map. it illustrate the crime frequency for each street in the philadelphia in the past two years(2016-2017).

## Steps to Create this Project
- data preparation (crime data cleanning; shapefile data transformation and write to Postgres)
- speed up spatial query preparation ( create index and write sf to Postgres)
- spatial query( for each crime, find its nearest street segment (seg_id))
- SQL query ( based on (seg_id) to calculate the number of crimes for each street segment)
- Using ggplot to visualize it
## Crime Levle Criteria
- low level : 1 crime happened in the past two years
- medium level: 2-3 crimes happend in the past two years
- high level : 4-8 crims happened in the past two years


## Data Scale
I only have processed around 15,000 crime data. It takes 20 mins to run the spatial query. So although the final result(crime level) is low, I will not update the crime data to a bigger scale, becuase it takes too long to run.
The data scale is a drawback for this project.

## Below is the map I created showing the crime level for each street:
![alt text](https://github.com/fangnandu/Street-Crime-level/blob/master/final%20crime%20frequency%20map.png "Logo Title Text 1")


### From this map, we can draw several conclusions:
- Most of the streets in Philadelphia has low crime risk
- The safest streets are most located in the west phily and northwestern part of Philadelphia
- As we can expect, the central part of Philadelphia have relative high risk for crime accurance for each street
- The northeastern part of Philadelphia also have several street segment is obviously high crime risk. The police should pay attention to these street segments.
