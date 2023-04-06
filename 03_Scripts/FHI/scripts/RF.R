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



### Train and test RF model ###

## Single RF ##

# # train <- upSample(train, train$CLASS_SAN3)[,-c(67)] #downSample 
# rf <- randomForest(CLASS_SAN3~., data=train, nree=500, proximity=TRUE, cutoff=CUTOFF)
# p1<-predict(rf,test)
# cM <-confusionMatrix(p1, test$CLASS_SAN3)
# confusionMatrix(p1, test$CLASS_SAN3)
# Kappa(cM[["table"]],r = 1,alternative = c("two.sided"),conf.level = 0.95,partial = FALSE)[1]

# # average OOB-error against the number of trees.
# model$err.rate[,1] - the i-th element being the (OOB) error rate for all trees up to the i-th.
# rf$err.rate[,1]
# plot(rf$err.rate[,1],type = "l",xlab = "# of trees", ylab = "Out-of-bag error",main = "RF with param struct (on 2.5m or seg), VHI and NDVI_diff")

# # Number of descriptor to test at branch split
# tuneRF(data[,-c(1,2)], data$CLASS_SAN3, ntreeTry=400, stepFactor=2, improve=0.01,trace=TRUE, plot=TRUE, doBest=FALSE)

# randomForest::varImpPlot(model, sort=FALSE, main=paste0("Variable Importance Plot at ",SIM_FOLDER," m"))

## Visualize proximity in dataset
# corrplot(rf$proximity[train$CLASS_SAN3==10, train$CLASS_SAN3==20], method='color', is.corr=FALSE) # show proximity


## k-fold tuning ##
i=0
train_control<- trainControl(method="cv", number=5, sampling="up", summaryFunction = mySummary)
ntree <- seq(100,1000,100)

# line 105 to 149 may be run several times to check the stability of the outputs
tuning <- sapply(ntree, function(ntr){
  tuneGrid <- expand.grid(.mtry = c(5: 11))
  model <- train(CLASS_SAN3~., data=train, trControl=train_control, 
                 tuneGrid=tuneGrid, metric="fdr", method="rf", ntree=ntr, 
                 cutoff=CUTOFF,importance=TRUE, maximize=FALSE)
  var_imp=caret::varImp(model)
  accuracy <- sum(predict(model,test) == test$CLASS_SAN3)/length(test$CLASS_SAN3)
  cf <- confusionMatrix(predict(model,test), test$CLASS_SAN3)
  fdr <- (cf[["table"]][1,2]+cf[["table"]][1,3]+cf[["table"]][2,3])/sum(cf[["table"]][,2:3]) #false detection rate
  return(c(accuracy,fdr,model,var_imp))
})

i=i+1
tiff(file=paste0(SIM_DIR,i,"_Accuracy.tif"),res=100,width = 1000, height = 500)
plot(ntree, tuning[1,], xlab = "Number of trees", ylab = "Accuracy",main = "Best RF models vs. number of trees")
text(ntree, as.numeric(tuning[1,])-0.002, labels=tuning[8,])
dev.off()

tiff(file=paste0(SIM_DIR,i,"_CustomMetric.tif"),res=100,width = 1000, height = 500)
plot(ntree, tuning[2,], xlab = "Number of trees", ylab = "Custom metric (to minimize)",main = "Best RF models vs. number of trees")
text(ntree, as.numeric(tuning[2,])-0.002, labels=tuning[8,])
dev.off()

########## MANUAL CHANGE HERE ###########
# Chose the best model
best_model<-tuning[,4]
########## MANUAL CHANGE HERE ###########

tiff(file=paste0(SIM_DIR,i,"_VarImp.tif"),res=100, width = 1000, height = 1000)
plot(best_model$finalModel$importance[,5],row.names(best_model$finalModel$importance[,1]),
     xlab = "Descriptor index", ylab = "Mean Decrease in Gini's index",main = "Descriptors importance")
text(best_model$finalModel$importance[,5]-0.1,row.names(best_model$finalModel$importance[,1]),labels=row.names(best_model$finalModel$importance),cex=0.75)
dev.off()

out<-best_model$results
cM <-confusionMatrix(predict(best_model$finalModel,test), test$CLASS_SAN3)

out_fname = paste0(SIM_DIR,i,"_out.csv")
cM_fname = paste0(SIM_DIR,i,"_cM.csv")
desc_fname = paste0(SIM_DIR,i,"_desc.csv")

write.table(out, file = out_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)
write.table(cM$table, file = cM_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)
write.table(cbind(row.names(best_model$finalModel$importance),best_model$finalModel$importance[,5]), file = desc_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)


