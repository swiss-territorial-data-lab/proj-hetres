#> This script trains and tests a Random Forest with the health class 
#> (10-health, 20-declining, 30-dead) as response variable. It loads several types
#> of descriptors : structural parameters, variation of yearly NDVI and RGBNIR stats. 
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
library(sf)
library(terra)

set.seed(2)

source("scripts/functions/functions.R")


### Define simulation parameters ###
Sys.setenv(R_CONFIG_ACTIVE = "default")
config <- config::get(file="config/config_RF.yml")

WORKING_DIR <- config$WORKING_DIR
RF_DIR <- config$RF_DIR
SIM_DIR <- config$SIM_DIR

DESC <- config$DESCRIPTORS
CUTOFF <- config$CUTOFF


setwd(WORKING_DIR)

### Dataset for Random Forest ###
data_all <- read.csv(paste0(RF_DIR,"all_desc_GT_nohf_poly.csv"))
data_topredict <- read.csv(paste0(RF_DIR,"all_desc_seg_hf_poly.csv"))

## Choose descriptors ##
data = switch(  
  DESC,  
  "all"= data_all[,c("ID","CLASS_SAN","zq99_seg","alpha_seg","beta_seg","cvlad_seg","vci_seg","i_mean_seg","i_sd_seg","CC","sdcc","sdchm","agl",
                     "NDVI_diff_1615","NDVI_diff_1716","NDVI_diff_1817","NDVI_diff_1918","NDVI_diff_2019","NDVI_diff_2120","NDVI_diff_2221",
                     "b_min","b_max","b_mean","b_std","b_median","r_min","r_max","r_mean","r_std","r_median","g_min","g_max","g_mean","g_std","g_median","nir_min","nir_max","nir_mean",
                     "nir_std","nir_median","ndvi_min","ndvi_max","ndvi_mean","ndvi_std","ndvi_median")],
  "NDVI_diff" = data_all[,c("ID","CLASS_SAN","NDVI_diff_1615","NDVI_diff_1716","NDVI_diff_1817","NDVI_diff_1918","NDVI_diff_2019","NDVI_diff_2120","NDVI_diff_2221")], 
  "structural" = data_all[,c("ID","CLASS_SAN","zq99_seg","alpha_seg","beta_seg","cvlad_seg","vci_seg","i_mean_seg","i_sd_seg","CC","sdcc","sdchm","agl")],
  "stats" = data_all[,c("ID","CLASS_SAN","b_min","b_max","b_mean","b_std","b_median","r_min","r_max","r_mean","r_std","r_median","g_min","g_max","g_mean","g_std","g_median",
                        "nir_min","nir_max","nir_mean","nir_std","nir_median","ndvi_min","ndvi_max","ndvi_mean","ndvi_std","ndvi_median")]
) 

data_topredict <-na.omit(data_topredict)
data_topredict <- switch(
  DESC,  
  "all"= data_topredict[,c("ID","CLASS_SAN","zq99_seg","alpha_seg","beta_seg","cvlad_seg","vci_seg","i_mean_seg","i_sd_seg","CC","sdcc","sdchm","agl",
                     "NDVI_diff_1615","NDVI_diff_1716","NDVI_diff_1817","NDVI_diff_1918","NDVI_diff_2019","NDVI_diff_2120","NDVI_diff_2221",
                     "b_min","b_max","b_mean","b_std","b_median","r_min","r_max","r_mean","r_std","r_median","g_min","g_max","g_mean","g_std","g_median","nir_min","nir_max","nir_mean",
                     "nir_std","nir_median","ndvi_min","ndvi_max","ndvi_mean","ndvi_std","ndvi_median")],
  "NDVI_diff" = data_topredict[,c("ID","CLASS_SAN","NDVI_diff_1615","NDVI_diff_1716","NDVI_diff_1817","NDVI_diff_1918","NDVI_diff_2019","NDVI_diff_2120","NDVI_diff_2221")], 
  "structural" = data_topredict[,c("ID","CLASS_SAN","zq99_seg","alpha_seg","beta_seg","cvlad_seg","vci_seg","i_mean_seg","i_sd_seg","CC","sdcc","sdchm","agl")],
  "stats" = data_topredict[,c("ID","CLASS_SAN","b_min","b_max","b_mean","b_std","b_median","r_min","r_max","r_mean","r_std","r_median","g_min","g_max","g_mean","g_std","g_median",
                        "nir_min","nir_max","nir_mean","nir_std","nir_median","ndvi_min","ndvi_max","ndvi_mean","ndvi_std","ndvi_median")]
)

## Choose response variable ##
data<- na.omit(data)
data<-data[data$ID!=102,]
data<-data[data$ID!=112,]
data<-data[data$ID!=190,]
data<-data[data$ID!=227,]
data<-data[data$ID!=96,] # nodata in LiDAR descriptor set
#data<-data[data$ID!=304,] # nodata in downgraded data
#data<-data[data$ID!=47,] # nodata in NDVI_diff point descriptor set						
data$CLASS_SAN <- as.factor(data$CLASS_SAN)
data$CLASS_SAN<- ordered(data$CLASS_SAN, levels =c("10","20","30")) 


### Define train and test dataset ###
inds <- partition(data$CLASS_SAN, p = c(train = 0.7, test = 0.3))
train_out <- data[inds$train, ]
test_out <- data[inds$test, ]

train <- subset(train_out, select = -c(1))
test <- subset(test_out, select = -c(1))


### Train and test RF model ###

## k-fold tuning ##
train_control <- trainControl(method="cv", number=5, sampling="up", summaryFunction = summaryRFmetrics)
ntree <- seq(100,1000,100)

tuning <- sapply(ntree, function(ntr){
  tuneGrid <- expand.grid(.mtry = c((round(sqrt(length(train)-1))-round(sqrt(length(train)-1)/2)): (round(sqrt(length(train)-1))+round(sqrt(length(train)-1)/2))))
  model <- train(CLASS_SAN~., data=train, trControl=train_control, 
                 tuneGrid=tuneGrid, metric="fdr", method="rf", ntree=ntr, 
                 cutoff=CUTOFF, importance=TRUE, maximize=FALSE)
  var_imp <- caret::varImp(model)
  accuracy <- sum(predict(model,test) == test$CLASS_SAN)/length(test$CLASS_SAN)
  cf <- confusionMatrix(predict(model,test), test$CLASS_SAN)
  fdr <- (cf[["table"]][1,2]+cf[["table"]][1,3]+cf[["table"]][2,3])/sum(cf[["table"]][,2:3]) #false detection rate
  return(c(accuracy,fdr,model,var_imp))
})

tiff(file=paste0(RF_DIR,DESC,"_Accuracy.tif"),res=100,width = 1000, height = 500)
plot(ntree, tuning[1,], xlab = "Number of trees", ylab = "Accuracy",main = "Best RF models vs. number of trees")
text(ntree, as.numeric(tuning[1,])-0.002, labels=tuning[8,])
dev.off()

tiff(file=paste0(RF_DIR,DESC,"_CustomMetric.tif"),res=100,width = 1000, height = 500)
plot(ntree, tuning[2,], xlab = "Number of trees", ylab = "Custom metric (to minimize)",main = "Best RF models vs. number of trees")
text(ntree, as.numeric(tuning[2,])-0.002, labels=tuning[8,])
dev.off()

########## Chose the best model (best_model<-tuning[,i]) ###########
if (sum(tuning[1,]==max(as.data.frame(tuning[1,])) & tuning[2,]==min(as.data.frame(tuning[2,])))==1) {
  best_model<-tuning[,which((tuning[1,]==max(as.data.frame(tuning[1,])) & tuning[2,]==min(as.data.frame(tuning[2,]))),arr.ind=TRUE)]
}else if (sum(tuning[1,]==max(as.data.frame(tuning[1,])) & tuning[2,]==min(as.data.frame(tuning[2,])))>1) {
  best_model<-tuning[,which((tuning[1,]==max(as.data.frame(tuning[1,])) & tuning[2,]==min(as.data.frame(tuning[2,]))),arr.ind=TRUE)][,1]
}else if (sum(tuning[2,]==min(as.data.frame(tuning[2,])))>1) {
  best_model<-tuning[,which((tuning[2,]==min(as.data.frame(tuning[2,]))),arr.ind=TRUE)][,1]
}else{
  best_model<-tuning[,which((tuning[2,]==min(as.data.frame(tuning[2,]))),arr.ind=TRUE)]
}

rf_beech<-best_model$finalModel
save(rf_beech,file = paste0(RF_DIR,DESC,"_rf_beech.RData"))
rm(rf_beech)

########## Chose the best model ###########

tiff(file=paste0(RF_DIR,DESC,"_VarImp.tif"),res=100, width = 1000, height = 1000)
plot(best_model$finalModel$importance[,5],row.names(best_model$finalModel$importance[,1]),
     xlab = "Descriptor index", ylab = "Mean Decrease in Gini's index",main = "Descriptors importance")
text(best_model$finalModel$importance[,5]-0.1,row.names(best_model$finalModel$importance[,1]),labels=row.names(best_model$finalModel$importance),cex=0.75)
dev.off()

out<-best_model$results
best_model$results
cf <-confusionMatrix(predict(best_model$finalModel,test), test$CLASS_SAN)
cf
fdr <- (cf[["table"]][1,2]+cf[["table"]][1,3]+cf[["table"]][2,3])/sum(cf[["table"]][,2:3]) #false detection rate
fdr
wgthd_kappa <- as.numeric(Kappa(cf[["table"]],r = 1,alternative = c("two.sided"),conf.level = 0.95,partial = FALSE)[1])
wgthd_kappa

out_fname = paste0(RF_DIR,DESC,"_best_model.csv")
cf_fname = paste0(RF_DIR,DESC,"_confusion_matrix.csv")
desc_fname = paste0(RF_DIR,DESC,"_important_descriptors.csv")
pred_fname = paste0(RF_DIR,DESC,"_testset_prediction.csv")

write.table(out, file = out_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)
write.table(cf$table, file = cf_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)
write.table(cbind(row.names(best_model$finalModel$importance),best_model$finalModel$importance[,5]), file = desc_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)

pred_test<- predict(best_model$finalModel,test)
test_scores <- predict(best_model$finalModel,test,"prob")
pred_test <- cbind(test_out, pred_test)
pred_test <- cbind(pred_test, test_scores)
pred_test$pred_sc <- apply(test_scores, 1, max)
write.csv(pred_test,pred_fname,row.names=FALSE)



# ### Prediction
pred <- predict(best_model$finalModel,data_topredict[,-c(1)])
pred_scores <-as.data.frame(predict(best_model$finalModel,data_topredict[,-c(1)],"prob"))
pred_scores$pred_sc <- apply(pred_scores, 1, max)
pred <-cbind(data_topredict[,c(1)],pred)
pred <-cbind(pred,pred_scores)
names(pred)<-c("ID","pred", "prb_sain", "prb_déclin","prb_mort", "prb_pred")

coord <-st_read(paste0(SIM_DIR,"mosaic_seg_params.shp"))

coord_pred <- merge(coord,pred, by.x = "segID", by.y = "ID")
st_write(coord_pred, paste0(RF_DIR,DESC,"_pred.shp"),append=FALSE)
