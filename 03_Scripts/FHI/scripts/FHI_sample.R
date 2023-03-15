library(raster)
library(pracma)
library(EnvStats)
library(corrplot)
library(Hmisc)
library(dendextend)
library(lidR)
library(terra)
library(sf)
library(caret)

source("03_Scripts/FHI/scripts/functions.R")

### Define parameters ###
res_cell <- 2.5


### Load LAS files ###

# ctg <- readLAScatalog("C:/Users/cmarmy/Documents/STDL/Beeches/DFT/data/sample/", select = "xyzc")
ctg <- readLAS("C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/las/2573700_1260500.las")
# plot(ctg, size = 3, map = TRUE)

ctg <- filter_poi(ctg, Classification >= 2 & Classification <=5 )



### Load corresponding extent from SHP Emprise ###
mySHP <- st_read("C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/extent/2573700_1260500.shp")
myExt <- extent(mySHP)



### Normalized point cloud ###

## with ground points
nlas <- normalize_height(ctg, knnidw())
#plot(nlas, size = 3, map = TRUE) 
#hist(filter_ground(nlas)$Z, breaks = seq(-0.6, 0.6, 0.01), main = "", xlab = "Elevation") #check normalized ground point to zero.


## with DTM
# nlas <- ctg - dtm
# plot(nlas, size = 4, bg = "white")



### DTM, CHM, AGL ###

## DTM : there are three methods with pro and cons.
# dtm<- rasterize_terrain(ctg, res=res_cell, algorithm = knnidw(k = 10L, p = 2)) # if no buffer available
# dtm<- rasterize_terrain(ctg, res=res_cell, algorithm = tin()) # if buffer available, like with catalog engine
# plot_dtm3d(dtm, bg = "white") 
# plot(dtm, col = gray(1:50/50))


## CHM (Canopy Height Model)
chm <- rasterize_canopy(nlas, res=res_cell/10, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smoothing 

writeRaster(chm, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/chm.tif", overwrite=TRUE)

fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(mean(x, na.rm = TRUE)) } else { return(x[i]) }}
w <- matrix(1, 3, 3)

chm_filled <- terra::focal(chm, w, fun = fill.na)
chm_smoothed <- terra::focal(chm_filled, w, fun = mean, na.rm = TRUE)

chms <- c(chm, chm_filled, chm_smoothed)
names(chms) <- c("Base", "Filled", "Smoothed")
col <- height.colors(25)
plot(chms, col = col)

writeRaster(chm_smoothed, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/chm_smoothed.tif", overwrite=TRUE)


## AGL (Above Ground Level)
agl <- rasterize_canopy(filter_poi(nlas, Classification >= 2 & Classification <=3 ), res=res_cell/10, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smooting 
col <- height.colors(25)
plot(agl, col = col)

writeRaster(agl, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/agl.tif", overwrite=TRUE)


## NaN handling (borders, no aquisitions) ##
chm_crop <- crop(chm_smoothed, myExt, snap="near", extend=FALSE)
chm_ext <-extend(chm_crop, myExt, fill=NA)
mask_<- pixel_metrics(ctg, ~mean(Z), res_cell) # NEW
mask_ext <- extend(mask_, myExt, fill=NA)
values(mask_ext)[is.na(values(mask_ext))]=1000
values(mask_ext)[values(mask_ext)<1000]=NA
mask_ext_10 <- aggregate(mask_ext, 10, fun=mean, na.rm=TRUE)

rm(ctg)

### STRUCTURAL PARAMETERS ###

# 1.	99 percentile height. > 2m
# 2.	Two parameters Weibull-density. alpha = scale
# 3.  Two parameters Weibull-density. beta = shape
# 4.	Coefficient of Variation of Leaf Area Density. !! Higher for smaller dz, because more contrast in above and below the thin layer. A large layer make some buffer effect !!
# 5.	Vertical Complexity Index. !! The entropy we are seeing is depending of dz !!
# 6.	CHM standard deviation. 
# 7.  Canopy Cover. > 2m
# 8.	Standard deviation of Canopy cover. 

# 6. CHM standard deviation
sdchm <- aggregate(chm_ext, 10, fun=sd, na.rm=TRUE) # 10 = number of cell vert. and horz. to aggregate
plot(sdchm, col = col)
names(sdchm)<-'sdchm'

chm_crop <- crop(chm_smoothed, myExt, snap="near", extend=FALSE)
chm_ext <-extend(chm_crop, myExt, fill=NA)

mask_ext[is.na(values(sdchm))]=800
values(sdchm)[is.na(values(sdchm))] = 0 #if no points 

# writeRaster(sdchm, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/sdchm.tif", overwrite=TRUE)


myM <- pixel_metrics(nlas, ~myMetrics(Z, ReturnNumber), res = res_cell) 
plot(myM, col = height.colors(50))  
#values(myM)[is.na(values(myM))] = 0

#writeRaster(myM, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/myM.tif", overwrite=TRUE)


CC_1m <- pixel_metrics(nlas, ~myMetrics_1m(Z, ReturnNumber), res = res_cell/10)
plot(CC_1m,col=col)

fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(0) } else { return(x[i]) }}
w <- matrix(1, 3, 3)
CC_1m_filled <- terra::focal(CC_1m, w, fun = fill.na)
plot(CC_1m_filled, col = col)

CC_1m_crop<- crop(CC_1m_filled, myExt, snap="near", extend=FALSE)
CC_1m_ext <-extend(CC_1m_crop, myExt, fill=NA)

sdCC <- aggregate(CC_1m_ext[[1]], 10, fun=sd, na.rm=TRUE)
plot(sdCC, col = col)


## NaN handling (borders, no aquisitions) ##
names(myM)<-c("zq99","alpha","beta","cvLAD","VCI","CC")
myM_crop <- crop(myM, myExt, snap="near", extend=FALSE)
myM_ext <-extend(myM_crop, myExt, fill=NA)
mask_ext[is.na(values(myM_ext["zq99"]))]=100
mask_ext[is.na(values(myM_ext["alpha"]))]=200
mask_ext[is.na(values(myM_ext["alpha"]))]=300
mask_ext[is.na(values(myM_ext["cvLAD"]))]=400
mask_ext[is.na(values(myM_ext["VCI"]))]=500
mask_ext[is.na(values(myM_ext["CC"]))]=600
values(myM_ext)[is.na(values(myM_ext))]=0
mask_ext[is.infinite(values(myM_ext["zq99"]))]=100
mask_ext[is.infinite(values(myM_ext["alpha"]))]=200
mask_ext[is.infinite(values(myM_ext["alpha"]))]=300
mask_ext[is.infinite(values(myM_ext["cvLAD"]))]=400
mask_ext[is.infinite(values(myM_ext["VCI"]))]=500
mask_ext[is.infinite(values(myM_ext["CC"]))]=600
values(myM_ext)[is.infinite(values(myM_ext))]=0

sdCC_crop <- crop(sdCC, myExt, snap="near", extend=FALSE)
sdCC_ext <-extend(sdCC_crop, myExt, fill=NA)
mask_ext[is.na(values(sdCC_ext))]=700
values(sdCC_ext)[is.na(values(sdCC_ext))]=0

## Put everything together (SpatRaster and table)
params_spat <- c(myM_ext, sdCC_ext, sdchm)
params_frame<-data.frame(params_spat)
data <- params_frame[, c(1,2,3,4,5,6,7,8)]


## Write outputs ##
writeRaster(params_spat, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/_params/test_params.tif", overwrite=TRUE)
plot(params_spat, col=col, nc=4,cex.main = 1.5)


writeRaster(mask_ext, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/_mask/test_mask.tif", overwrite=TRUE)

