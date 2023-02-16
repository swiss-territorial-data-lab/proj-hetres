library(raster)
library(pracma)
library(EnvStats)
library(corrplot)
library(Hmisc)
library(dendextend)
library(lidR)

myMetrics <- function(z, rn)
{
  # for 2., 3. and 4.
  dz <- 1 # thickness of the elevation level
  h <- max(z)-min(z) # max(z[z>2])-min(z[z>2])
  n <- floor(h)/dz  # number of elevation level
  
  if (h<1){
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
      CHP[k] <- sum(z>hp*(k-1) & z<=hp*k)/sum(z>0)
      if (CHP[k]<0){ CHP[k]=0}
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
    
    if (sum(CHP==0)>=5){
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
      GF[i] <- (sum(z<dz*(i-1) & z>0)+1)/((sum(z>0)+2)*(sum(z>dz*i)+1)) # +1, at least one point in layer
      LADh[i] = -log(GF[i])/kappa*dz
    }
    
    cvLAD <- sqrt(1/(n-1)*sum((LADh-mean(LADh))^2))/mean(LADh) 
    
    
    # 4. Vertical Complexity Index
    P <- vector()
    for (k in 1:n){
      P[k] <- (sum(z>dz*(k-1)&z<=dz*k)+1)/(sum(z>0)+1) # +1, at least one point in layer
    }
    
    mVCI <- -dot(P,log(P))/log(n) #VCI(nlas@data$Z, 30, by = 1)
    
    
    # 6. Canopy Cover
    first  <- rn == 1L
    zfirst <- z[first]
    nfirst <- length(zfirst)
    above2 <- sum(z > 2)
    
    CC <- above2/nfirst*100
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
  first  <- rn == 1L
  zfirst <- z[first]
  nfirst <- length(zfirst)
  above2 <- sum(z > 2)
  
  CC <- above2/nfirst*100
  
  if (above2 == 0){
    above2=1
  }
  if (nfirst==0){
    nfirst=1
  }
  if (is.infinite(CC)){CC=NaN}
  
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
  name <- gsub('[C:/Users/cmarmy/Desktop/test/las/.las]','',str)
  mySHP<- st_read(paste0('C:/Users/cmarmy/Desktop/test/extent/',name,'.shp'))
  myExt <-extent(mySHP)
  
  
  
  ### Normalized point cloud ###
  nlas <- normalize_height(las_f, knnidw())
  
  
  
  ### DTM, CHM, AGL ###
  
  ## CHM (Canopy Height Model)
  chm <- rasterize_canopy(nlas, res=1, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smooting 
  #writeRaster(chm, "C:/Users/cmarmy/Desktop/test/chm.tif", overwrite=TRUE)
  
  fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(mean(x, na.rm = TRUE)) } else { return(x[i]) }}
  w <- matrix(1, 3, 3)
  
  chm_filled <- terra::focal(chm, w, fun = fill.na)
  chm_smoothed <- terra::focal(chm_filled, w, fun = mean, na.rm = TRUE)
  #writeRaster(chm_smoothed, "C:/Users/cmarmy/Desktop/test/chm_smoothed.tif", overwrite=TRUE)
  
  
  ## AGL (Above Ground Level)
  agl <- rasterize_canopy(filter_poi(nlas, Z >= 0.5 & Z <=10 ), res=1, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smooting 
  # writeRaster(agl, "C:/Users/cmarmy/Desktop/test/agl.tif", overwrite=TRUE)
  
  
  
  ### NaN handling (borders, no aquisitions) ###
  chm_crop <- crop(chm_smoothed, myExt, snap="near", extend=FALSE)
  chm_ext <-extend(chm_crop, myExt, fill=0)
  values(chm_ext)[is.na(values(chm_ext))]=0
  mask_<- pixel_metrics(las, ~mean(Z), 1)
  mask_ext <- extend(mask_, myExt, fill=NA)
  
  
  
  ### STRUCTURAL PARAMETERS ###
  
  # 1.	99 percentile height.
  # 2.	Two parameter Weibull-density. 
  # 3.	Coefficient of Variation of Leaf Area Density. 
  # 4.	Vertical Complexity Index. 
  # 5.	CHM standard deviation. 
  # 6.	Standard deviation of Canopy cover. 
  
  # 5. CHM standard deviation
  sdchm <- aggregate(chm_smoothed, 10, fun=sd) # 10 = number of cell vert. and horz. to aggregate
  values(sdchm)[is.na(values(sdchm))] = 0 #if no points 
  
  # 1., 2., 3. and 4. 
  myM <- pixel_metrics(nlas, ~myMetrics(Z, ReturnNumber), res = 10)
  values(myM)[is.na(values(myM))] = 0 #if no points 
  
  
  # 6.Standard deviation of Canopy Cover
  CC_1m <- pixel_metrics(nlas, ~myMetrics_1m(Z, ReturnNumber), res = 1)
  
  fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(0) } else { return(x[i]) }}
  w <- matrix(1, 3, 3)
  CC_1m_filled <- terra::focal(CC_1m, w, fun = fill.na)
  
  sdCC <- aggregate(CC_1m_filled[[1]], 10, fun=sd, na.action=1)
  
  ## Put everything together (SpatRaster and table)
  params_spat <- c(sdchm, myM, sdCC)
  sdchm_frame<-as.data.frame(sdchm)
  myM_frame<-as.data.frame(myM)
  sdCC_frame<-as.data.frame(sdCC)
  params_frame<-data.frame(sdchm_frame, myM_frame, sdCC_frame)
  data <- params_frame[, c(1,2,3,4,5,6,7,8)]
  
  #writeRaster(params_spat, "C:/Users/cmarmy/Desktop/test/params_spat_{*}.tif", overwrite=TRUE)
  writeRaster(params_spat, paste0(chunk@save,".tif"), overwrite=TRUE)
  #paste0(chunk@save,".tif")
  
  las_out <- filter_poi(nlas, buffer == 0) # remove buffer
  return(las_out)
}

ctg <- readLAScatalog("C:/Users/cmarmy/Desktop/test/las/", select = "xyzcrn")
opt_output_files(ctg) <- paste0("C:/Users/cmarmy/Desktop/test/", "/{*}_norm")
options <- list(automerge = TRUE)
output <- catalog_apply(ctg, norm_chunk,.options=options)



#### Ici, il faudra merger tous les raster ####
f <- "C:/Users/cmarmy/Desktop/test/params_spat_thd.tif"
r0 <- rast(f)

files <- list.files(path="C:/Users/cmarmy/Desktop/test/", pattern="*.tif", full.names=TRUE, recursive=FALSE)
for (f in files){
  r <- rast(f)
  rlist <- list(r0,r)
  rsrc <- sprc(rlist)
  r0 <- mosaic(rsrc)
}

writeRaster(r0, "C:/Users/cmarmy/Desktop/test/mosaic.tif", overwrite=TRUE)
