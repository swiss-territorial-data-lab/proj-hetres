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

# The procedure in this script is coming from P. Meng et al (2022), DOI: 10.1080/17538947.2022.2059114


### Define simulation parameters ###
res_cell <- 2.5
wkdir <- 'C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/_tmp/'
dir_las <- 'C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/_tmp/'
need_extent <- TRUE
dir_extent <- 'C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/extent/'

# NB: need_extent comments l.154, paragraph "Load corresponding extent from SHP Emprise" if 
# the used LAS tiles are perfect squares (point coverage = square extent).
# This is the case for the LAS files in las_swisstopo folder. 



##########################################

norm_chunk <- function(chunk){
  
  ### Load LAS file ###
  las <- readLAS(chunk)
  if (is.empty(las)) return(NULL)
  las_f = filter_poi(las, Classification >= 2 & Classification <=5 )
  
  ### Load corresponding extent from SHP Emprise ###
  if (need_extent==TRUE){
    str <- chunk@files[1]
    name <- sub(dir_las,'',str)
    name <- sub('.las','',name)
    mySHP <- st_read(paste0(dir_extent,name,'.shp'))
    myExt <- extent(mySHP)
  } else {
    myExt <- extent(las_f)
  }
  
  
  
  ### Normalized point cloud ###
  nlas <- normalize_height(las_f, knnidw())
  
  
  
  ### DTM, CHM, AGL ###
  
  # ## CHM (Canopy Height Model)
  chm <- rasterize_canopy(nlas, res=res_cell/10, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smooting 
  writeRaster(chm, paste0(chunk@save,"_chm.tif"), overwrite=TRUE)
  
  fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(mean(x, na.rm = TRUE)) } else { return(x[i]) }}
  w <- matrix(1, 3, 3)
  
  chm_filled <- terra::focal(chm, w, fun = fill.na)
  chm_smoothed <- terra::focal(chm_filled, w, fun = mean, na.rm = TRUE)
  
  
  ## AGL (Above Ground Level)
  agl <- rasterize_canopy(filter_poi(nlas, Classification >= 2 & Classification <=3), res=res_cell/10, pitfree(thresholds = c(0,5,10), max_edge = c(0, 1.5), subcircle = 0.15)) 
  writeRaster(agl, paste0(chunk@save,"_agl.tif"), overwrite=TRUE)
  
  
  
  ### NaN handling (borders, no aquisitions) ###
  chm_crop <- crop(chm_smoothed, myExt, snap="near", extend=FALSE)
  chm_ext <-extend(chm_crop, myExt, fill=NA)
  mask_<- pixel_metrics(nlas, ~mean(Z), res_cell)
  mask_crop<- crop(mask_, myExt, snap="near", extend=FALSE)
  mask_ext <- extend(mask_crop, myExt, fill=NA)
  values(mask_ext)[is.na(values(mask_ext))]=1000
  values(mask_ext)[values(mask_ext)<1000]=NA
  
  
  
  ### STRUCTURAL PARAMETERS ###
  
  # 1.	99 percentile height.
  # 2.	Two parameters Weibull-density.
  # 3.  Two parameters Weibull-density.
  # 4.	Coefficient of Variation of Leaf Area Density.
  # 5.	Vertical Complexity Index.
  # 6.	CHM standard deviation.
  # 7.  Canopy Cover.
  # 8.	Standard deviation of Canopy cover.
  
  # 6. CHM standard deviation
  sdchm <- aggregate(chm_ext, 10, fun=sd, na.rm=TRUE) # 10 = number of cell vert. and horz. to aggregate
  values(sdchm)[is.na(values(sdchm))] = 0 #if no points
  names(sdchm)<-'sdchm'
  
  mask_ext[is.na(values(sdchm))]=800
  values(sdchm)[is.na(values(sdchm))] = 0 #if no points 
  
  
  # 1., 2., 3. and 4.
  myM <- pixel_metrics(nlas, ~myMetrics(Z, ReturnNumber), res = res_cell)
  values(myM)[is.na(values(myM))] = 0 #if no points
  
  
  # 6.Standard deviation of Canopy Cover
  CC_1m <- pixel_metrics(nlas, ~myMetrics_1m(Z, ReturnNumber), res = res_cell/10)
  
  fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(0) } else { return(x[i]) }}
  w <- matrix(1, 3, 3)
  CC_1m_filled <- terra::focal(CC_1m, w, fun = fill.na)
  
  CC_1m_crop<- crop(CC_1m_filled, myExt, snap="near", extend=FALSE)
  CC_1m_ext <-extend(CC_1m_crop, myExt, fill=NA)
  
  sdCC <- aggregate(CC_1m_ext[[1]], 10, fun=sd, na.rm=TRUE)
  
  
  
  ### NaN handling (borders, no acquisitions) ###
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
  
  
  
  ### Write outputs ###
  writeRaster(params_spat, paste0(chunk@save,"_params.tif"), overwrite=TRUE)
  
  writeRaster(mask_ext, paste0(chunk@save,"_mask.tif"), overwrite=TRUE)
  
  
  #las_out <- filter_poi(nlas, buffer == 0) # remove buffer
  return(0)#return(las_out)
}

ctg <- readLAScatalog(dir_las, select = "xyzcrn")
#opt_output_files(ctg) <- paste0(wkdir, "/{*}")
options <- list(automerge = TRUE)
ctg@output_options$drivers$Raster$param$overwrite <- TRUE
ctg@output_options$drivers$Spatial$param$overwrite <- FALSE
output <- catalog_apply(ctg, norm_chunk,.options=options)



#### Merge the output rasters (params, mask, agl, ...) ####

merge_raster<-function(wkdir, extension, output){
  files <- list.files(path=wkdir, pattern=extension, full.names=TRUE, recursive=FALSE)
  
  r0 <- rast(files[1])
  for (f in files){
    r <- rast(f)
    rlist <- list(r0,r)
    rsrc <- sprc(rlist)
    r0 <- mosaic(rsrc)
  }
  
  writeRaster(r0, paste0(wkdir,output), overwrite=TRUE)
}

## Mosaic with parameters values, masks, agl,... 
merge_raster(wkdir,"*_params.tif",'mosaic_params.tif')
merge_raster(wkdir,"*_mask.tif",'mosaic_mask.tif')
merge_raster(wkdir,"*_agl.tif",'mosaic_agl.tif')


