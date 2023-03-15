library(config)
library(lidR)
library(sf)
library(terra)
library(EnvStats)
library(Hmisc)

source("C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/scripts/functions.R")



### Define parameters ###
Sys.setenv(R_CONFIG_ACTIVE = "default")
config <- config::get(file="C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/scripts/config.yml")

RES_CELL <- config$RES_CELL



### Load LAS file ###
las <- readLAS("C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/las/2574600_1260200.las")
# plot(las, size = 3, map = TRUE)

las <- filter_poi(las, Classification >= 2 & Classification <=5 )



### Load corresponding extent from SHP emprise ###
sample_shp <- st_read("C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/extent/2574600_1260200.shp")
sample_ext <- extent(sample_shp)



### Normalize point cloud ###

## with ground points
nlas <- normalize_height(las, knnidw())
#plot(nlas, size = 3, map = TRUE) 
#hist(filter_ground(nlas)$Z, breaks = seq(-0.6, 0.6, 0.01), main = "", xlab = "Elevation") #check normalized ground point to zero.


## with DTM
# nlas <- las - dtm
# plot(nlas, size = 4, bg = "white")



### DTM, CHM, AGL ###

## DTM : there are three methods with pro and cons.
# dtm <- rasterize_terrain(las, res=RES_CELL, algorithm = knnidw(k = 10L, p = 2)) # if no buffer available
# dtm <- rasterize_terrain(las, res=RES_CELL, algorithm = tin()) # if buffer available, like with catalog engine
# plot_dtm3d(dtm, bg = "white") 
# plot(dtm, col = gray(1:50/50))


## CHM (Canopy Height Model)
chm <- rasterize_canopy(nlas, res=RES_CELL/10, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smoothing 

# writeRaster(chm, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/sample_chm.tif", overwrite=TRUE)

fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(mean(x, na.rm = TRUE)) } else { return(x[i]) }}
w <- matrix(1, 3, 3)

chm_filled <- terra::focal(chm, w, fun = fill.na)
chm_smoothed <- terra::focal(chm_filled, w, fun = mean, na.rm = TRUE)

chms <- c(chm, chm_filled, chm_smoothed)
names(chms) <- c("Base", "Filled", "Smoothed")
col <- height.colors(25)
plot(chms, col = col)

# writeRaster(chm_smoothed, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/sample_chm_smoothed.tif", overwrite=TRUE)


## AGL (Above Ground Level)
agl <- rasterize_canopy(filter_poi(nlas, Classification >= 2 & Classification <=3 ), res=RES_CELL/10, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smooting 
col <- height.colors(25)
plot(agl, col = col)

writeRaster(agl, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/sample_agl.tif", overwrite=TRUE)


## NaN handling (borders, no aquisitions) 
chm_crop <- crop(chm_smoothed, sample_ext, snap="near", extend=FALSE)
chm_ext <-extend(chm_crop, sample_ext, fill=NA)
mask_<- pixel_metrics(las, ~mean(Z), RES_CELL) 
mask_ext <- extend(mask_, sample_ext, fill=NA)
values(mask_ext)[is.na(values(mask_ext))]=1000
values(mask_ext)[values(mask_ext)<1000]=NA
mask_ext_10 <- aggregate(mask_ext, 10, fun=mean, na.rm=TRUE)

rm(las)



### STRUCTURAL PARAMETERS ###

# 1.	99 percentile height. > 2m
# 2.	Two parameters Weibull-density. alpha = scale
# 3.  Two parameters Weibull-density. beta = shape
# 4.	Coefficient of Variation of Leaf Area Density. !! Higher for smaller dz, because more contrast in above and below the thin layer. A large layer make some buffer effect !!
# 5.	Vertical Complexity Index. !! The entropy we are seeing is depending of dz !!
# 6.	CHM standard deviation. 
# 7.  Canopy Cover. > 2m
# 8.	Standard deviation of Canopy cover. 


## 6. CHM standard deviation
sdchm <- aggregate(chm_ext, 10, fun=sd, na.rm=TRUE) # 10 = number of cell vert. and horz. to aggregate
plot(sdchm, col = col)
names(sdchm)<-'sdchm'

chm_crop <- crop(chm_smoothed, sample_ext, snap="near", extend=FALSE)
chm_ext <-extend(chm_crop, sample_ext, fill=NA)

mask_ext[is.na(values(sdchm))]=800
values(sdchm)[is.na(values(sdchm))] = 0 #if no points 

# writeRaster(sdchm, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/sample_sdchm.tif", overwrite=TRUE)


## Structural parameters 1., 2., 3., 4., 5 and 7.
sample_params <- pixel_metrics(nlas, ~metricsParams(Z, ReturnNumber), res = RES_CELL) 
plot(sample_params, col = height.colors(50))  

#writeRaster(sample_params, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/sample_sample_params.tif", overwrite=TRUE)


## 8. Standard deviation of Canopy Cover computation
cc_1m <- pixel_metrics(nlas, ~metricsParams1m(Z, ReturnNumber), res = RES_CELL/10)
plot(cc_1m,col=col)

fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(0) } else { return(x[i]) }}
w <- matrix(1, 3, 3)
cc_1m_filled <- terra::focal(cc_1m, w, fun = fill.na)
plot(cc_1m_filled, col = col)

cc_1m_crop<- crop(cc_1m_filled, sample_ext, snap="near", extend=FALSE)
cc_1m_ext <-extend(cc_1m_crop, sample_ext, fill=NA)

sdcc <- aggregate(cc_1m_ext[[1]], 10, fun=sd, na.rm=TRUE)
plot(sdcc, col = col)


## NaN handling (borders, no aquisitions) 
names(sample_params)<-c("zq99","alpha","beta","cvLAD","VCI","CC")
sample_params_crop <- crop(sample_params, sample_ext, snap="near", extend=FALSE)
sample_params_ext <-extend(sample_params_crop, sample_ext, fill=NA)
mask_ext[is.na(values(sample_params_ext["zq99"]))]=100
mask_ext[is.na(values(sample_params_ext["alpha"]))]=200
mask_ext[is.na(values(sample_params_ext["alpha"]))]=300
mask_ext[is.na(values(sample_params_ext["cvLAD"]))]=400
mask_ext[is.na(values(sample_params_ext["VCI"]))]=500
mask_ext[is.na(values(sample_params_ext["CC"]))]=600
values(sample_params_ext)[is.na(values(sample_params_ext))]=0
mask_ext[is.infinite(values(sample_params_ext["zq99"]))]=100
mask_ext[is.infinite(values(sample_params_ext["alpha"]))]=200
mask_ext[is.infinite(values(sample_params_ext["alpha"]))]=300
mask_ext[is.infinite(values(sample_params_ext["cvLAD"]))]=400
mask_ext[is.infinite(values(sample_params_ext["VCI"]))]=500
mask_ext[is.infinite(values(sample_params_ext["CC"]))]=600
values(sample_params_ext)[is.infinite(values(sample_params_ext))]=0

sdcc_crop <- crop(sdcc, sample_ext, snap="near", extend=FALSE)
sdcc_ext <-extend(sdcc_crop, sample_ext, fill=NA)
mask_ext[is.na(values(sdcc_ext))]=700
values(sdcc_ext)[is.na(values(sdcc_ext))]=0


## Put everything together (SpatRaster and table)
params_spat <- c(sample_params_ext, sdcc_ext, sdchm)
params_frame<-data.frame(params_spat)
data <- params_frame[, c(1,2,3,4,5,6,7,8)]


## Write outputs ##
writeRaster(params_spat, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/sample_params.tif", overwrite=TRUE)
plot(params_spat, col=col, nc=4,cex.main = 1.5)


writeRaster(mask_ext, "C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/sample_mask.tif", overwrite=TRUE)

