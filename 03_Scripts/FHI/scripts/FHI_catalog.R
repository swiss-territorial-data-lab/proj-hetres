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


### Define simulation parameters ###
res_cell <- 2.5
wkdir <- 'C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/res2p5/'
dir_las <- 'C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/las/'
dir_extent <- 'C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/extent/'



##########################################

myMetrics <- function(z, rn)
{
  # for 2., 3. and 4.
  dz <- 5 # thickness of the elevation level
  zmax <- max(z)
  h <- zmax-min(z) # max(z[z>2])-min(z[z>2])
  n <- floor(h)/dz  # number of elevation level
  
  if (h<2){ #if to low vegetation make it then higher ?
    alpha=0
    beta=0
    cvLAD=0
    mVCI=0
    CC = 0
  } else {
    
    #2. Weibull's scale and shape parameters
    hp = h/10 # height percentiles
    CHP <- vector() # point density per height percentiles
    for (k in 1:10){
      CHP[k] <- sum(z>=hp*(k-1) & z<hp*k)/sum(z>=0)
      if (sum(z>=0)==0){
        CHP[k]=0
      }
    }
    
    # interpolate if CHP==0
    for (k in 2:9){
      if (CHP[k] == 0) {
        CHP[k] = abs(CHP[k+1]+CHP[k-1])/2
      }
    }
    if (CHP[1] == 0){
      CHP[1] = CHP[2]/2
    }
    if (CHP[10] == 0){
      CHP[10] = CHP[9]/2
    }
    
    if (sum(CHP==0)>=3){
      alpha = 0
      beta = 0
    }else{
      wb <- eweibull(CHP, method = "mle")
      alpha <- wb[["parameters"]][["scale"]]
      beta <- wb[["parameters"]][["shape"]]
    }
    
    
    ## 3.
    kappa <- 0.67 # see literature
    GF <- vector()
    LADh <- vector()
    # GF[1] <- 1/((sum(z>0)+1)*sum(z>dz)) # +1, at least one point in layer
    # LADh[1] = -log(GF[1])/kappa*dz
    for (i in 1:n){
      GF[i] <- (sum(z<dz*(i-1) & z>=0)+1)/((sum(z>=0)+2)*(sum(z>dz*i)+1)) # +1, at least one point in layer
      LADh[i] = -log(GF[i])/kappa*dz
    }
    
    cvLAD <- sqrt(1/(n-1)*sum((LADh-mean(LADh))^2))/mean(LADh)
    
    
    # 4. Vertical Complexity Index
    P <- vector()
    for (k in 1:n){
      P[k] <- (sum(z>=dz*(k-1)&z<dz*k)+1)/(sum(z>=0)+1) # +1, at least one point in layer
    }
    
    mVCI <- -dot(P,log(P))/log(n) #VCI(nlas@data$Z, 30, by = 1)
    
    
    # 6.
    first  = rn == 1L
    zfirst = z[first]
    nfirst = length(zfirst)
    firstabove2 = sum(zfirst > 2)
    x = (firstabove2/nfirst)*100
    
    CC <- (firstabove2/nfirst)*100 # no first is possible, if in filtered classes
  }
  
  metrics <- list(
    zq99=stats::quantile(z[z>2], 0.99),
    alpha=alpha,
    beta=beta,
    cvLAD=cvLAD,
    mVCI=mVCI,
    # sdCHM = done on smoothed chm
    CC = CC
    # sdCC = do it afterward on CC 
  )
  
  return(c(metrics))
}

myMetrics_1m <- function(z, rn)
{
  # 6.
  first  = rn == 1L 
  zfirst = z[first]
  nfirst = length(zfirst)
  firstabove2 = sum(zfirst > 2)
  x = (firstabove2/nfirst)*100
  
  CC <- (firstabove2/nfirst)*100 # no first is possible, if in filtered classes
  
  metrics <- list(
    sdCC = CC
  )
  
  return(c(metrics))
}


norm_chunk <- function(chunk)
{
  
 ### Load LAS file ###
  
 las <- readLAS(chunk)
 if (is.empty(las)) return(NULL)
 las_f = filter_poi(las, Classification >= 2 & Classification <=5 )
 
 

 ### Load corresponding extent from SHP Emprise ###
 str <- chunk@files[1]
 name <- sub(dir_las,'',str)
 name <- sub('.las','',name)
 mySHP<- st_read(paste0(dir_extent,name,'.shp'))
 myExt <-extent(mySHP)
 
 
 
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
 #values(chm_ext)[is.na(values(chm_ext))]=0
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



 # ## Write outputs ##
 # writeRaster(params_spat, paste0(chunk@save,"_params.tif"), overwrite=TRUE)
 # 
 # writeRaster(mask_ext, paste0(chunk@save,"_mask.tif"), overwrite=TRUE)


 #las_out <- filter_poi(nlas, buffer == 0) # remove buffer
 return()#return(las_out)
}

ctg <- readLAScatalog(dir_las, select = "xyzcrn")
opt_output_files(ctg) <- paste0(wkdir, "/{*}")
options <- list(automerge = TRUE)
ctg@output_options$drivers$Raster$param$overwrite <- TRUE
ctg@output_options$drivers$Spatial$param$overwrite <- FALSE
output <- catalog_apply(ctg, norm_chunk,.options=options)



# TODO : MAKE A MOSAIC FUNCTION, GENERALIZE PATH !!

#### Merge the rasters and the masks ####

## Mosaïc with parameters values
files <- list.files(path=wkdir, pattern="*_params.tif", full.names=TRUE, recursive=FALSE)

r0 <- rast(files[1])
for (f in files){
  r <- rast(f)
  rlist <- list(r0,r)
  rsrc <- sprc(rlist)
  r0 <- mosaic(rsrc)
}

writeRaster(r0, paste0(wkdir,'mosaic.tif'), overwrite=TRUE)


## Mosaïc of masks
files <- list.files(path=wkdir, pattern="*_mask.tif", full.names=TRUE, recursive=FALSE)

r0 <- rast(files[1])
for (f in files){
  r <- rast(f)
  rlist <- list(r0,r)
  rsrc <- sprc(rlist)
  r0 <- mosaic(rsrc)
}

writeRaster(r0, paste0(wkdir,'mosaic_mask.tif'), overwrite=TRUE)


## AGL mosaïc
files <- list.files(path=wkdir, pattern="*_agl.tif", full.names=TRUE, recursive=FALSE)

r0 <- rast(files[1])
for (f in files){
  r <- rast(f)
  rlist <- list(r0,r)
  rsrc <- sprc(rlist)
  r0 <- mosaic(rsrc)
}

writeRaster(r0, paste0(wkdir,'mosaic_agl.tif'), overwrite=TRUE)