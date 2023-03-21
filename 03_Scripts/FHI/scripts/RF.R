library(config)
library(sf)
library(terra)
library(randomForest)
library(caret)
library(varImp)
library(corrplot)



# This script trains and tests a Random Forest with the health parameters as 
# descriptors and with the health class (10-health, 20-declining, 30-dead) as 
# response variable. 

# INPUTS: 
# - ground truth with attributes (SHP)
# - mosaïc of the health parameters (TIF)

# OUTPUTS:
# - confusion matrix for Random Forest (in the console)

# PARAMETERS #

Sys.setenv(R_CONFIG_ACTIVE = "production")
config <- config::get(file="C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/scripts/config.yml")

SIM_DIR <- config$SIM_DIR
SIM_FOLDER <- config$SIM_FOLDER
PATH_GT <- config$PATH_GT


#### Link GT & parameters ####

GT <- st_read(PATH_GT)


## Params on segmentation shapes
seg_params <- st_read(paste0(SIM_DIR,"mosaic_seg_params.shp"))
st_crs(seg_params) = st_crs(GT)
seg_params$segID <- seq.int(nrow(seg_params)) 
GT_params<-st_join(GT, seg_params, left=FALSE, right=FALSE)
GT_params <- GT_params[,-c(52)]


# Chose only the polygones corresponding to the GT. 
# GT_params<-st_join(seg_params, GT, left=FALSE, right=FALSE)
# st_write(GT_params,"C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/GT/GT_segFun.shp", driver = "ESRI Shapefile", append=TRUE)



## Params from aerial imagery
# image_params <- st_read("C:/Users/cmarmy/Downloads/beech_stats.gpkg")
# blue_b <- image_params[image_params$band=="bleu",][,-c(6,7)]
# names(blue_b) = c("b_min","b_max","b_mean","b_std", "b_median","geom")
# GT_params<-st_join(GT_params,blue_b)
# 
# red_b <- image_params[image_params$band=="bleu",][,-c(6,7)]
# names(red_b) = c("r_min","r_max","r_mean","r_std", "r_median","geom")
# GT_params<-st_join(GT_params,red_b)
# 
# green_b <- image_params[image_params$band=="bleu",][,-c(6,7)]
# names(green_b) = c("g_min","g_max","g_mean","g_std", "g_median","geom")
# GT_params<-st_join(GT_params,green_b)
# 
# nir_b <- image_params[image_params$band=="proche IR",][,-c(6,7)]
# names(nir_b) = c("nir_min","nir_max","nir_mean","nir_std", "nir_median","geom")
# GT_params<-st_join(GT_params,nir_b)

 
## Params on grid cells
ras_params <- rast(paste0(SIM_DIR, "mosaic_params.tif"))
GT_params<- extract(ras_params, GT_params, fun=NULL, method="simple", cells=FALSE, xy=FALSE,
                    ID=TRUE, weights=FALSE, exact=FALSE,layer=NULL, bind=TRUE, raw=FALSE)



## Final dataframe with all parameters
mydata<-as.data.frame(GT_params)



### Create Random Forest model ###


## Choose descriptors ##

# with NDVI_diff ONLY
data<-mydata[,c(4,6,11,12,9,8,10,13,7)]

# with VHI_only
data<-mydata[,c(4,6,14,15,16,18,17,19,20)]

# with bands from aerial images ONLY 
data<-mydata[,c(4,6,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73)]

# with structural parameters ONLY
data<-mydata[,c(4,6,47,48,49,50,51,58,59,60)]

# with structural parameters, NDVI_diff and VHI
data<-mydata[,c(4,6,11,12,9,8,10,13,7,14,15,16,17,18,19,20,47,48,49,50,51,58,59,60)]

# with AGL 
agl <- rast(paste0(SIM_DIR,"mosaic_agl.tif"))
zonal_val <- extract(agl,GT_params, as.raster=FALSE, as.polygons=TRUE)
names(zonal_val)<-c("ID","agl")
zonal_val[is.na(zonal_val)]=0
zonal_val <- zonal_val[-c(1)]
data <-cbind(data,zonal_val)


write.csv(data, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/RF_data.csv", row.names=FALSE)

## Choose response variable ##

data<-na.omit(data)
data$CLASS_SAN3 <- as.factor(data$CLASS_SAN3)
# table(GT$CLASS_SAN3)


### Define train and test dataset ###
set.seed(222)
ind <- sample(2, nrow(data), replace = TRUE, prob = c(0.7, 0.3))
train_out<- data[ind==1,]
test_out <- data[ind==2,]
train <- subset(train_out, select = -c(1))
test <- subset(test_out, select = -c(1))


### Train RF model ###

rf <- randomForest(CLASS_SAN3~., data=train, ntree=500, proximity=TRUE, cutoff=c(0.375,0.25,0.375))
p1<-predict(rf,test)
confusionMatrix(p1, test$CLASS_SAN3)
# print(rf)


# corrplot(rf$proximity[train$CLASS_SAN3==10, train$CLASS_SAN3==10], method='color', is.corr=FALSE) # show proximity

## average OOB-error against the number of trees. ##
# model$err.rate[,1] - the i-th element being the (OOB) error rate for all trees up to the i-th.
rf$err.rate[,1]
plot(rf$err.rate[,1],type = "l",xlab = "# of trees", ylab = "Out-of-bag error",main = "RF with param struct (on 2.5m or seg), VHI and NDVI_diff")


## Number of descriptor for test at branch 
tuneRF(data[,-c(1,2)], data$CLASS_SAN3, ntreeTry=400, stepFactor=2, improve=0.01,trace=TRUE, plot=TRUE, doBest=FALSE)


## kfold cross-validation ##

# define training control
train_control<- trainControl(method="cv", number=5)

tuneGrid <- expand.grid(.mtry = c(2: 6))
# train the model 
model<- train(CLASS_SAN3~., data=train, trControl=train_control, tuneGrid=tuneGrid, method="rf", ntree=2000, cutoff=c(0.3,0.3,0.4))
model

# make predictions
predictions<- predict(model,train)

# append predictions
#train<- cbind(train,predictions)

# summarize results
# confusionMatrix<- confusionMatrix(train$predictions,train$CLASS_SAN3)
# confusionMatrix

p2 <- predict(model, test)
confusionMatrix(p2, test$CLASS_SAN3)






# --------------- begin loop ablation study --------------------------

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

for (i in 2:l){ 
  
  
  rf <- randomForest(CLASS_SAN3~., data=train[,-c(i)], ntree=500, proximity=TRUE, cutoff=c(0.3,0.3,0.4))
  
  
  ## Variable importance ##
  
  tiff(file=paste0(SIM_DIR,SIM_FOLDER,list_sim[i],"VarImp.tif"),res=100)
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
  
  writeVector(vect(GT_merge),paste0("C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/",paste0(SIM_FOLDER,list_sim[i]),"pred_out.shp"), filetype=NULL, layer=NULL, insert=FALSE,overwrite=TRUE, options="ENCODING=UTF-8")

}

##---------------------------------------------------------------------------------







