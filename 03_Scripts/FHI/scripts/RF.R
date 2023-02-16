library(randomForest)
library(datasets)
library(caret)
library(terra)

myshp <- vect("C:/Users/cmarmy/Documents/STDL/Beeches/GT/GT_Z_beechesAOI_corr_attribute_poly.shp")
myras<-rast("C:/Users/cmarmy/Documents/STDL/Beeches/FHI/mosaic.tif")
mydata <- zonal(myras,myshp, as.raster=FALSE, as.polygons=TRUE)

myshp <-vect("C:/Users/cmarmy/Documents/STDL/Beeches/FHI/GT_Z_beechesAOI_corr_attribute_poly_zonal.shp")
mydata<-as.data.frame(myshp)
data<-mydata[,c(25,27,28,29,30,31,32,33,34)]

data$class_san3 <- as.factor(data$class_san3)
table(myshp$class_san3)

set.seed(222)
ind <- sample(2, nrow(data), replace = TRUE, prob = c(0.7, 0.3))
train <- data[ind==1,]
test <- data[ind==2,]

rf <- randomForest(class_san3~., data=train, proximity=TRUE) 
print(rf)


p1 <- predict(rf, train)
confusionMatrix(p1, train$class_san3)


p1 <- predict(rf, test)
confusionMatrix(p1, test$class_san3)
