#> This script trains an Ordinal Forest and computes prediction with the health class 
#> (10-health, 20-declining, 30-dead) as response variable. It loads several types
#> of descriptors : structural parameters, NDVI and VHI indices, RGBNIR stats. 
#> 
#> INPUTS:
#> - CSV with descriptors and response variable. 
#> 
#> OUTPUTS: 
#> - confusion matrix (in console)

library(config)
library(ordinalForest)

source("C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/scripts/functions.R")

set.seed(222)



### Define simulation parameters ###
Sys.setenv(R_CONFIG_ACTIVE = "production")
config <- config::get(file="C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/scripts/config.yml")

SIM_DIR <- config$SIM_DIR
SIM_FOLDER <- config$SIM_FOLDER
SIM_STATS <- config$SIM_STATS
PATH_GT <- config$PATH_GT
DESC <- config$DESCRIPTORS
CUTOFF <- config$CUTOFF



### Dataset for Ordinal Forest ###
data_all <- read.csv(paste0(SIM_DIR,"all_desc.csv"))


## Choose descriptors ##
data = switch(  
  DESC,  
  "all"= data_all,
  "NDVI_diff" = data_all[,c(1:9)],
  "VHI" = data_all[,c(1,2,10:16)],
  "Structural params" = data_all[,c(1,2,17:27)],
  "Stats&PCA" = data_all[,c(1,2,28:67)]
)  


## Choose response variable ##
data<-na.omit(data)
data$CLASS_SAN3 <- as.factor(data$CLASS_SAN3)
data$CLASS_SAN3<- ordered(data$CLASS_SAN3, levels =c("10", "20","30")) 



### Define train and test dataset ###
inds <- partition(data$CLASS_SAN3, p = c(train = 0.7, test = 0.3))
train_out <- data[inds$train, ]
test_out <- data[inds$test, ]

train <- subset(train_out, select = -c(1))
test <- subset(test_out, select = -c(1))


### Train and predict model ###

ordforres <- ordfor(depvar="CLASS_SAN3", data=train, nsets=50, nbest=5, ntreeperdiv=100, 
                    ntreefinal=1000)
# NOTE: nsets=50 is not enough, because the prediction performance of the resulting 
# ordinal forest will be suboptimal!! In practice, nsets=1000 (default value) or a 
# larger number should be used.

ordforres

sort(ordforres$varimp, decreasing=TRUE)

pred_of<-predict(ordforres,test)

confusionMatrix(pred_of$ypred, test$CLASS_SAN3)


