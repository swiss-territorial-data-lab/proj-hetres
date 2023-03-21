library(config)
library(lidR)
library(sf)
library(terra)
library(EnvStats)
library(pracma)

source("C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/scripts/functions.R")

#> INPUTS
#> OUTPUTS
#> params_rasters
#> params_segments (SHP TO MERGE)



# The procedure in this script is coming partly from P. Meng et al (2022), DOI: 10.1080/17538947.2022.2059114



### Define simulation parameters ###
Sys.setenv(R_CONFIG_ACTIVE = "production")
config <- config::get(file="C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/scripts/config.yml")

RES_CELL <- config$RES_CELL
SIM_DIR <- config$SIM_DIR
DIR_LAS <- config$DIR_LAS
NEED_EXTENT <- config$NEED_EXTENT
DIR_EXTENT <- config$DIR_EXTENT



# NB: NEED_EXTENT comments l.154, paragraph "Load corresponding extent from SHP emprise" if 
# the used LAS tiles are perfect squares (point coverage = square extent).
# This is the case for the LAS files in las_swisstopo folder. 



##########################################



norm_chunk <- function(chunk){
  
  ### Load LAS file ###
  las <- readLAS(chunk)
  las <- add_attribute(las, las$label, "treeID")
  if (is.empty(las)) return(NULL)
  las_f = filter_poi(las, Classification >= 2 & Classification <=5 )
  
  
  
  ### Load corresponding extent from SHP ###
  if (NEED_EXTENT==TRUE){
    str <- chunk@files[1]
    name <- sub(DIR_LAS,'',str)
    name <- sub('.las','',name)
    las_shp <- st_read(paste0(DIR_EXTENT,name,'.gpkg'))
    las_ext <- extent(las_shp)
  } else {
    las_ext <- extent(las_f)
  }
  
  
  
  ### Normalized point cloud ###
  nlas <- normalize_height(las_f, knnidw())
  
  
  
  ### DTM, CHM, AGL ###
  
  # ## CHM (Canopy Height Model)
  chm <- rasterize_canopy(nlas, res=RES_CELL/10, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smoothing 
  writeRaster(chm, paste0(chunk@save,"_chm.tif"), overwrite=TRUE)
  
  fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(mean(x, na.rm = TRUE)) } else { return(x[i]) }}
  w <- matrix(1, 3, 3)
  
  chm_filled <- terra::focal(chm, w, fun = fill.na)
  chm_smoothed <- terra::focal(chm_filled, w, fun = mean, na.rm = TRUE)
  
 
  ## AGL (Above Ground Level)
  agl <- rasterize_canopy(filter_poi(nlas, Classification >= 2 & Classification <=3), res=RES_CELL/10, pitfree(thresholds = c(0,5,10), max_edge = c(0, 1.5), subcircle = 0.15)) 
  writeRaster(agl, paste0(chunk@save,"_agl.tif"), overwrite=TRUE)
  
  
  
  ### NaN handling (borders, no aquisitions) ###
  chm_crop <- crop(chm_smoothed, las_ext, snap="near", extend=FALSE)
  chm_ext <-extend(chm_crop, las_ext, fill=NA)
  mask_<- pixel_metrics(nlas, ~mean(Z), RES_CELL)
  mask_crop<- crop(mask_, las_ext, snap="near", extend=FALSE)
  mask_ext <- extend(mask_crop, las_ext, fill=NA)
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
  
  ## 6. CHM standard deviation
  sdchm <- aggregate(chm_ext, 10, fun=sd, na.rm=TRUE) # 10 = number of cell vert. and horz. to aggregate
  values(sdchm)[is.na(values(sdchm))] = 0 #if no points
  names(sdchm)<-'sdchm'
  
  mask_ext[is.na(values(sdchm))]=800
  values(sdchm)[is.na(values(sdchm))] = 0 #if no points 
  
  
  ## Structural parameters 1., 2., 3., 4., 5 and 7.
  las_params <- pixel_metrics(nlas, ~metricsParams(Z, ReturnNumber), res = RES_CELL)
  values(las_params)[is.na(values(las_params))] = 0 #if no points
  
  
  ## 8.Standard deviation of Canopy Cover
  cc_1m <- pixel_metrics(nlas, ~metricsParams1m(Z, ReturnNumber), res = RES_CELL/10)
  
  fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(0) } else { return(x[i]) }}
  w <- matrix(1, 3, 3)
  cc_1m_filled <- terra::focal(cc_1m, w, fun = fill.na)
  
  cc_1m_crop<- crop(cc_1m_filled, las_ext, snap="near", extend=FALSE)
  cc_1m_ext <-extend(cc_1m_crop, las_ext, fill=NA)
  
  sdcc <- aggregate(cc_1m_ext[[1]], 10, fun=sd, na.rm=TRUE)
  
  
  
  ### NaN handling (borders, no acquisitions) ###
  names(las_params)<-c("zq99","alpha","beta","cvLAD","VCI","CC")
  las_params_crop <- crop(las_params, las_ext, snap="near", extend=FALSE)
  las_params_ext <-extend(las_params_crop, las_ext, fill=NA) 
  mask_ext[is.na(values(las_params_ext["zq99"]))]=100
  mask_ext[is.na(values(las_params_ext["alpha"]))]=200
  mask_ext[is.na(values(las_params_ext["alpha"]))]=300
  mask_ext[is.na(values(las_params_ext["cvLAD"]))]=400
  mask_ext[is.na(values(las_params_ext["VCI"]))]=500
  mask_ext[is.na(values(las_params_ext["CC"]))]=600
  values(las_params_ext)[is.na(values(las_params_ext))]=0
  mask_ext[is.infinite(values(las_params_ext["zq99"]))]=100 
  mask_ext[is.infinite(values(las_params_ext["alpha"]))]=200
  mask_ext[is.infinite(values(las_params_ext["alpha"]))]=300
  mask_ext[is.infinite(values(las_params_ext["cvLAD"]))]=400
  mask_ext[is.infinite(values(las_params_ext["VCI"]))]=500
  mask_ext[is.infinite(values(las_params_ext["CC"]))]=600
  values(las_params_ext)[is.infinite(values(las_params_ext))]=0
  
  sdcc_crop <- crop(sdcc, las_ext, snap="near", extend=FALSE)
  sdcc_ext <-extend(sdcc_crop, las_ext, fill=NA)
  mask_ext[is.na(values(sdcc_ext))]=700
  values(sdcc_ext)[is.na(values(sdcc_ext))]=0
  
  
  ## Put everything together (SpatRaster and table)
  params_spat <- c(las_params_ext, sdcc_ext, sdchm)
  params_frame<-data.frame(params_spat)
  data <- params_frame[, c(1,2,3,4,5,6,7,8)]
  
  
  
  ### Write outputs ###
  writeRaster(params_spat, paste0(chunk@save,"_params.tif"), overwrite=TRUE)
  
  writeRaster(mask_ext, paste0(chunk@save,"_mask.tif"), overwrite=TRUE)
  
  
  
  ### Structural parameter computation by segment ###
  nlas <- filter_poi(nlas, buffer == 0) # remove buffer
  
  # ...
  ccm = ~crownMetricsParams(z = Z, label=treeID, rn = ReturnNumber, intnst=Intensity)
  
  seg_params <- crown_metrics(nlas, func = ccm, geom = "concave") # ’point’, ’convex’, ’concave’ or ’bbox’.
  
  

  return(seg_params)
}

ctg <- readLAScatalog(DIR_LAS)
opt_output_files(ctg) <- paste0(SIM_DIR, "/{*}")
options <- list(automerge = TRUE)
ctg@output_options$drivers$Raster$param$overwrite <- TRUE
ctg@output_options$drivers$Spatial$param$overwrite <- FALSE
output <- catalog_apply(ctg, norm_chunk,.options=options)



#### Merge the output rasters (params, mask, agl, ...) and shapes ####
mergeRaster(SIM_DIR,"*_params.tif",'mosaic_params.tif')
mergeRaster(SIM_DIR,"*_mask.tif",'mosaic_mask.tif')
mergeRaster(SIM_DIR,"*_agl.tif",'mosaic_agl.tif')

mergeVector(SIM_DIR,"*seg.shp","mosaic_seg_params.shp")

