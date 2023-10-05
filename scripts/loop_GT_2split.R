#> This script performs two test on the quality of the random forest model : 
#>  1. tests the model for 5 different random seed
#>  2. remove progRessively one individuals from the training set, before training 
#>     and assessing the model on the test set. 
#> 
#> INPUTS:
#>  - parameter file
#>  - CSV with instances and descriptors
#>   
#> OUTPUTS: 
#>  - CSV for each random seed
#>  - corresponding graphics
#>  - corresponding GPKG of test and train sets. 



library(lctools)
library(config)
library(randomForest)
library(splitTools)
library(caret)
library(varImp)
library(Metrics)
library(DeltaMAN)
library(sf)
library(terra)

source("C:/Users/cmarmy/Documents/STDL/Beeches/delivery/proj-hetres/scripts/functions.R")



### Define simulation parameters ###
Sys.setenv(R_CONFIG_ACTIVE = "production")
config <- config::get(file="C:/Users/cmarmy/Documents/STDL/Beeches/delivery/proj-hetres/config/config_gt.yml")

SIM_DIR <-config$SIM_DIR
SIM_FOLDER <- config$SIM_FOLDER
DESC <- config$DESCRIPTORS
CUTOFF <- config$CUTOFF
RF_PRED <- config$RF_PRED
GT_SHP <- config$PATH_GT

set.seed(2)

### Dataset for Random Forest ###
data_all <- read.csv(paste0(SIM_DIR,"desc_GT_new_nohf_poly_2p5m.csv"))


## Choose descriptors ##
data = switch(  
  DESC,  
  "all"= data_all[,c(1,2,4:10,18:21,22:28,29:53)],# c(1:2,4:10,19:29,55:74)]
  "NDVI_diff" = data_all[,c(1,2,23:29)],#4:10,19:22
  "Structural params" = data_all[,c(1,2,4:10,19:22)], # choice : 5:10,19,21,
  "PCA" = data_all[,c(1,2,55:74)],
  "Sat&PCA" = data_all[,c(1,2,30:79)],
  "custom" =  data_all[,c(1:9,10,14,15,17,19:25,27,53,54,58,59,63,64)]
)  


## Choose response variable ##
data<- na.omit(data)
data<-data[data$ID!=102,]
data<-data[data$ID!=112,]
data<-data[data$ID!=190,]
data<-data[data$ID!=227,]
data<-data[data$ID!=96,] # nodata in LiDAR descriptor set
data$CLASS_SAN <- as.factor(data$CLASS_SAN)
data$CLASS_SAN<- ordered(data$CLASS_SAN, levels =c("10","20","30")) 



### Define train and test datasets ###
# load(paste0(SIM_DIR,"ID_test.RData"))
# ind <- is.element(data$ID,tmp)
# test_out<- data[ind,]
# train_out<- data[!ind,]

# ### Define train and test datasets ###
inds <- partition(data$CLASS_SAN, p = c(train = 0.7, test = 0.3))
train_out <- data[inds$train, ]
test_out <- data[inds$test, ]

train <- subset(train_out, select = -c(1))
test <- subset(test_out, select = -c(1))
# table(test$CLASS_SAN)
# table(train$CLASS_SAN)



### Moran's Index
coord <-st_read(GT_SHP)

coord_test <- merge(coord[,c(1,3,4)],test_out[,c(1,2)], by.x = "NO_ARBRE", by.y = "ID")
nocoord_test<-st_drop_geometry(coord_test)
moran_test<-moransI(nocoord_test[,c(1,2)], 10, as.numeric(test$CLASS_SAN), WType = 'Binary')

# coord_data <- merge(coord[,c(1,2,4)],data, by.x = "NO_ARBRE", by.y = "ID")
# coord_data<-st_drop_geometry(coord_data)
# moransI(coord_data[,c(2,3)], 10, as.numeric(data$CLASS_SAN), WType = 'Binary')


### Looping on random seed and training set ablation ###

for (k in c(2,22,222,2222,22222)){
  
  ### Set random seed
  set.seed(k)
  
  ### Define train and test datasets ###
  inds <- partition(train_out$CLASS_SAN, p = c(train = 0.7, test = 0.3))
  train_out_ss <- train_out[inds$train, ]
  
  train_ss <- subset(train_out_ss, select = -c(1))
  
  coord_train_ss <- merge(coord[,c(1,2,4)],train_out_ss, by.x = "NO_ARBRE", by.y = "ID")
  st_write(coord_train_ss, driver="GPKG", paste0(SIM_DIR,k,"_trainset.gpkg"),append=FALSE)
  coord_train_ss<-st_drop_geometry(coord_train_ss)
  moran_train<-moransI(coord_train_ss[,c(1,2)], 10, as.numeric(train_ss$CLASS_SAN), WType = 'Binary')
  
  coord_test_k <- coord_test
  coord_test_k$count <- 0
  
  ### Looping and ablating GT
  n <- nrow(train_ss)
  
  for (i in 1:1){#(n/10*9)
    
    ### Train and test RF model ###
    
    set.seed(k)
    
    ## k-fold tuning ##
    
    train_control <- trainControl(method="cv", number=5, sampling="up", summaryFunction = mySummary)
    ntree <- seq(100,1000,100)
    
    tuning <- sapply(ntree, function(ntr){
      tuneGrid <- expand.grid(.mtry = c((round(sqrt(length(train_ss)-1))-3): (round(sqrt(length(train_ss)-1))+3)))
      model <- train(CLASS_SAN~., data=train_ss, trControl=train_control, 
                     tuneGrid=tuneGrid, metric="fdr", method="rf", ntree=ntr, 
                     cutoff=CUTOFF,importance=TRUE, maximize=FALSE)
      var_imp <- caret::varImp(model)
      accuracy <- sum(predict(model,test) == test$CLASS_SAN)/length(test$CLASS_SAN)
      cf <- confusionMatrix(predict(model,test), test$CLASS_SAN)
      fdr <- (cf[["table"]][1,2]+cf[["table"]][1,3]+cf[["table"]][2,3])/sum(cf[["table"]][,2:3]) #false detection rate
      return(c(accuracy,fdr,model,var_imp))
    })
    
    # tiff(file=paste0(SIM_DIR,k,"_",i,"_Accuracy.tif"),res=100,width = 1000, height = 500)
    # plot(ntree, tuning[1,], xlab = "Number of trees", ylab = "Accuracy",main = "Best RF models vs. number of trees")
    # text(ntree, as.numeric(tuning[1,])-0.002, labels=tuning[8,])
    # dev.off()
    # 
    # tiff(file=paste0(SIM_DIR,k,"_",i,"_CustomMetric.tif"),res=100,width = 1000, height = 500)
    # plot(ntree, tuning[2,], xlab = "Number of trees", ylab = "Custom metric (to minimize)",main = "Best RF models vs. number of trees")
    # text(ntree, as.numeric(tuning[2,])-0.002, labels=tuning[8,])
    # dev.off()

    # Chose the best model
    if (sum(tuning[1,]==max(as.data.frame(tuning[1,])) & tuning[2,]==min(as.data.frame(tuning[2,])))==1) {
        best_model<-tuning[,which((tuning[1,]==max(as.data.frame(tuning[1,])) & tuning[2,]==min(as.data.frame(tuning[2,]))),arr.ind=TRUE)]
    }else if (sum(tuning[1,]==max(as.data.frame(tuning[1,])) & tuning[2,]==min(as.data.frame(tuning[2,])))>1) {
        best_model<-tuning[,which((tuning[1,]==max(as.data.frame(tuning[1,])) & tuning[2,]==min(as.data.frame(tuning[2,]))),arr.ind=TRUE)][,1]
    }else if (sum(tuning[2,]==min(as.data.frame(tuning[2,])))>1) {
        best_model<-tuning[,which((tuning[2,]==min(as.data.frame(tuning[2,]))),arr.ind=TRUE)][,1]
    }else{
        best_model<-tuning[,which((tuning[2,]==min(as.data.frame(tuning[2,]))),arr.ind=TRUE)]
    }
    
    # tiff(file=paste0(SIM_DIR,k,"_",i,"_VarImp.tif"),res=100, width = 1000, height = 1000)
    # plot(best_model$finalModel$importance[,5],row.names(best_model$finalModel$importance[,1]),
    #      xlab = "Descriptor index", ylab = "Mean Decrease in Gini's index",main = "Descriptors importance")
    # text(best_model$finalModel$importance[,5]-0.1,row.names(best_model$finalModel$importance[,1]),labels=row.names(best_model$finalModel$importance),cex=0.75)
    # dev.off()
	
  	respred <- predict(best_model$finalModel,test)
    coord_test_k$count <- coord_test_k$count+abs(as.numeric(respred)-as.numeric(coord_test_k$CLASS_SAN))
    coord_test_k <- cbind(coord_test_k, as.data.frame(as.numeric(respred)))
    names(coord_test_k)[ncol(coord_test_k)-1]<-paste0("ab_",i)
    
    cf <-confusionMatrix(predict(best_model$finalModel,test), test$CLASS_SAN)
    fdr <- (cf[["table"]][1,2]+cf[["table"]][1,3]+cf[["table"]][2,3])/sum(cf[["table"]][,2:3]) #false detection rate
    wgthd_kappa <- as.numeric(Kappa(cf[["table"]],r = 1,alternative = c("two.sided"),conf.level = 0.95,partial = FALSE)[1])
    sensitivity <- cf[["byClass"]][,1]
    
    out_fname = paste0(SIM_DIR,k,"_out.csv")
    out_line = cbind(train_out_ss[nrow(train_ss)+1,1],nrow(train_ss),fdr,wgthd_kappa,wgthd_kappa,cf[["overall"]][["Accuracy"]],t(sensitivity), t(cf[["table"]][1,]), t(cf[["table"]][2,]), t(cf[["table"]][3,]))
    write.table(out_line, file = out_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)
    
    if (i==1){
      moran_fname = paste0(SIM_DIR,"Moran.csv")
      out_line = cbind(k,moran_train[["Morans.I"]],moran_test[["Morans.I"]],fdr,wgthd_kappa,cf[["overall"]][["Accuracy"]],t(sensitivity), t(cf[["table"]][1,]), t(cf[["table"]][2,]), t(cf[["table"]][3,]))
      write.table(out_line, file = moran_fname, sep = ",", append = TRUE, quote = FALSE, col.names = FALSE, row.names = FALSE)
    }

    train_ss <- train_ss[-nrow(train_ss),]
    
  }
  
   st_write(coord_test_k,driver="GPKG", paste0(SIM_DIR,k,"_testset.gpkg"),append=FALSE)
}


for (k in c(2,22,222,2222,22222)){
  csv_data<-read.csv(paste0(SIM_DIR,k,"_out.csv"),header=F,sep=",")
  
  tiff(file=paste0(SIM_DIR,k,"_Sensitivity.PNG"),res=100, width = 1000, height = 1000)
  plot(csv_data[,c(7)],type='l', col='green', lwd=1, ylim=c(0,1), main=paste0("Stability for GT removal, seed = ",k), xlab="# of trees removed from GT", ylab="Specificity")
  lines(csv_data[,c(8)], type="l", col = "blue") 
  lines(csv_data[,c(9)], type="l", col = "red") 
  lines(csv_data[,c(6)], type="l", col = "black") 
  legend(x="topright",legend=c("healthy","unhealthy","dead","OA"), col=c('green','blue','red','black'), lwd=c(1,1,1))
  dev.off()
  
}


