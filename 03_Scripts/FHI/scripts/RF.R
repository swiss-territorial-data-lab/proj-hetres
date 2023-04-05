#> This script trains and tests a Random Forest with the health class 
#> (10-health, 20-declining, 30-dead) as response variable. It loads several types
#> of descriptors : structural parameters, NDVI and VHI indices, RGBNIR stats. 
#> 
#> INPUTS:
#> - CSV with descriptors and response variable. 
#> 
#> OUTPUTS: 
#> - confusion matrix (in console)


library(config)
library(randomForest)
library(splitTools)
library(caret)
library(varImp)
library(corrplot)
library(Metrics)
library(DeltaMAN)

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



### Dataset for Random Forest ###
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
# table(test$CLASS_SAN3)



### Define train and test dataset ###
inds <- partition(data$CLASS_SAN3, p = c(train = 0.7, test = 0.3))
train_out <- data[inds$train, ]
test_out <- data[inds$test, ]

train <- subset(train_out, select = -c(1))
test <- subset(test_out, select = -c(1))
# table(test$CLASS_SAN3)
# table(train$CLASS_SAN3)



### Train RF model ###

## Train unique RF ##
# train <- upSample(train, train$CLASS_SAN3)[,-c(67)] #downSample 
rf <- randomForest(CLASS_SAN3~., data=train, ntree=500, proximity=TRUE, cutoff=CUTOFF)
p1<-predict(rf,test)
cM <-confusionMatrix(p1, test$CLASS_SAN3)
confusionMatrix(p1, test$CLASS_SAN3)
Kappa(cM[["table"]],r = 1,alternative = c("two.sided"),conf.level = 0.95,partial = FALSE)[1]

train_control<- trainControl(method="none", sampling="up", summaryFunction = mySummary)
model<- train(CLASS_SAN3~., data=train, trControl=train_control, metric="fdr", method="rf", ntree=500, cutoff=CUTOFF, varImp=TRUE)
p1<-predict(model,test)
cM <-confusionMatrix(p1, test$CLASS_SAN3)
confusionMatrix(p1, test$CLASS_SAN3)
Kappa(cM[["table"]],r = 1,alternative = c("two.sided"),conf.level = 0.95,partial = FALSE)[1]

randomForest::varImpPlot(model, sort=FALSE, main=paste0("Variable Importance Plot at ",SIM_FOLDER," m"))

## average OOB-error against the number of trees. ##
# model$err.rate[,1] - the i-th element being the (OOB) error rate for all trees up to the i-th.
rf$err.rate[,1]
plot(rf$err.rate[,1],type = "l",xlab = "# of trees", ylab = "Out-of-bag error",main = "RF with param struct (on 2.5m or seg), VHI and NDVI_diff")


## Number of descriptor to test at branch split
tuneRF(data[,-c(1,2)], data$CLASS_SAN3, ntreeTry=400, stepFactor=2, improve=0.01,trace=TRUE, plot=TRUE, doBest=FALSE)


## Visualize proximity in dataset
# corrplot(rf$proximity[train$CLASS_SAN3==10, train$CLASS_SAN3==20], method='color', is.corr=FALSE) # show proximity


## k-fold version
train_control<- trainControl(method="cv", number=5, sampling="up", summaryFunction = mySummary)
tuneGrid <- expand.grid(.mtry = c(6: 10))

model<- train(CLASS_SAN3~., data=train, trControl=train_control, tuneGrid=tuneGrid, metric="fdr",method="rf", ntree=2000, cutoff=CUTOFF)
model

predictions<- predict(model,test)
confusionMatrix(predictions, test$CLASS_SAN3)



### --------------- begin loop ablation study --------------------------###

#> Hypothèse : on a différent types de paramètres (NDVI, VHI, structuraux, images).
#> Je veux vérifier lesquels aident à classifier correctement, lesquels brouillent 
#> le signal.  
#> Baseline : tous là pour une catégorie, j'en enlève un à la fois. 
#>


# list_sim = c("san","1617", "1718", "1819", "1920", "2021", "2122")
# list_sim = c("san","zq99","alpha","beta","cvLAD","VCI","CC","sdCC","sdchm","agl")
# list_sim = c("san","16", "17", "18", "19", "20", "21","22")
# list_sim = c("san","1617", "1718", "1819", "1920", "2021", "2122","16", "17", "18", "19", "20", "21","22","zq99","alpha","beta","cvLAD","VCI","CC","sdCC","sdchm","agl")
list_sim = names(train)
l = length(list_sim)


# sample csv name
file.remove("C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/metrics.csv")
csv_fname = "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/metrics.csv"
# writing row in the csv file
write.table(data.frame("SIM_FOLDER", "ablation", "OA","TPR[sain]", "TPR[declin]", "TPR[mort]"), file = csv_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)

rf <- randomForest(CLASS_SAN3~., data=train, ntree=500, proximity=TRUE, cutoff=CUTOFF)
# writing row in the csv file
row <- data.frame(SIM_FOLDER, 'baseline', OA,TPR[1], TPR[2], TPR[3])
write.table(row, file = csv_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)


for (i in 2:l){ 
  
  rf <- randomForest(CLASS_SAN3~., data=train[,-c(i)], ntree=500, proximity=TRUE, cutoff=CUTOFF)
  
  ## Variable importance ##
  
  tiff(file=paste0(SIM_DIR,list_sim[i],"VarImp.tif"),res=100)
  randomForest::varImpPlot(rf, sort=FALSE, main=paste0("Variable Importance Plot at ",SIM_FOLDER," m"))
  dev.off()
  
  
  ### Test model and outputs ###
  
  p1 <- predict(rf, test[,-c(i)])
  cM<-confusionMatrix(p1, test$CLASS_SAN3)
  OA <- as.data.frame(cM["overall"])[1,1]
  TPR <- as.data.frame(cM["byClass"])[,1]
  row <- data.frame(SIM_FOLDER, list_sim[i], OA,TPR[1], TPR[2], TPR[3])
  cM
  
  # sample csv name
  csv_fname = "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/metrics.csv"
  
  # writing row in the csv file
  write.table(row, file = csv_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)
  
  ## Output prediction for visualization ##
  pred_out<-cbind(test_out[,c("NO_ARBRE")],p1)
  GT_merge <- merge(GT,pred_out, all.x=TRUE, by.x=c('NO_ARBRE'), by.y=c('V1'))
  
  writeVector(vect(GT_merge),paste0(SIM_DIR,list_sim[i],"pred_out.shp"), filetype=NULL, layer=NULL, insert=FALSE,overwrite=TRUE, options="ENCODING=UTF-8")

}

###---------------------------------------------------------------------------------