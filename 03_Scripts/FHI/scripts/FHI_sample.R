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


# --- Questions --- #
# ?? Does it make sens to define threshold with clustering on one varialbes ? 
# que veut dire une entropy de zéro en terme de distribution ? 

# --- Remarques --- #
# GF, LAD and VCI from package not use, because not directly usable in pixel_metrics
# le fait d'ajouter un point quand il n'y en a pas.
# Gestion des Inf, mis à NaN puis filled by mean. 



### Load LAS files ###

# ctg <- readLAScatalog("C:/Users/cmarmy/Documents/STDL/Beeches/DFT/data/sample/", select = "xyzc")
ctg <- readLAS("C:/Users/cmarmy/Documents/STDL/Beeches/FHI/las/2577600_1260200.las")
# plot(ctg, size = 3, map = TRUE)

ctg = filter_poi(ctg, Classification >= 2 & Classification <=5 )



### Load corresponding extent from SHP Emprise ###
mySHP<- st_read("C:/Users/cmarmy/Documents/STDL/Beeches/FHI/extent/2577600_1260200.shp")
myExt <-extent(mySHP)



### Normalized point cloud ###

## with ground points
nlas <- normalize_height(ctg, knnidw())
#plot(nlas, size = 3, map = TRUE) 
#hist(filter_ground(nlas)$Z, breaks = seq(-0.6, 0.6, 0.01), main = "", xlab = "Elevation") #check normalized groud point to zero.


## with DTM
# nlas <- ctg - dtm
# plot(nlas, size = 4, bg = "white")



### DTM, CHM, AGL ###

## DTM : there are three methods with pro and cons.
# dtm<- rasterize_terrain(ctg, res=1, algorithm = knnidw(k = 10L, p = 2)) # if no buffer available
# dtm<- rasterize_terrain(ctg, res=1, algorithm = tin()) # if buffer available, like with catalog engine
# plot_dtm3d(dtm, bg = "white") 
# plot(dtm, col = gray(1:50/50))


## CHM (Canopy Height Model)
chm <- rasterize_canopy(nlas, res=0.5, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smooting 

writeRaster(chm, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/chm.tif", overwrite=TRUE)

fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(mean(x, na.rm = TRUE)) } else { return(x[i]) }}
w <- matrix(1, 3, 3)

chm_filled <- terra::focal(chm, w, fun = fill.na)
chm_smoothed <- terra::focal(chm_filled, w, fun = mean, na.rm = TRUE)

chms <- c(chm, chm_filled, chm_smoothed)
names(chms) <- c("Base", "Filled", "Smoothed")
col <- height.colors(25)
plot(chms, col = col)

writeRaster(chm_smoothed, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/chm_smoothed.tif", overwrite=TRUE)


## AGL (Above Ground Level)
agl <- rasterize_canopy(filter_poi(nlas, Z >= 0.5 & Z <=10 ), res=0.5, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smooting 
col <- height.colors(25)
plot(agl, col = col)

writeRaster(agl, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/agl.tif", overwrite=TRUE)


## NaN handling (borders, no aquisitions) ##
chm_crop <- crop(chm_smoothed, myExt, snap="near", extend=FALSE)
chm_ext <-extend(chm_crop, myExt, fill=NA)
#values(chm_ext)[is.na(values(chm_ext))]=0
mask_<- pixel_metrics(ctg, ~mean(Z), 1)
mask_ext <- extend(mask_, myExt, fill=NA)
mask_ext_10 <- aggregate(mask_ext, 10, fun=mean, na.rm=TRUE)



### STRUCTURAL PARAMETERS ###

# 1.	99 percentile height. > 2m
# 2.	Two parameters Weibull-density. alpha = scale
# 3.  Two parameters Weibull-density. beta = shape
# 4.	Coefficient of Variation of Leaf Area Density. !! Higher for smaller dz, because more contraste in above and below the thin layer. A large layer make some buffer effect !!
# 5.	Vertical Complexity Index. !! The entropy we are seeing is depending of dz !!
# 6.	CHM standard deviation. 
# 7.  Canopy Cover. > 2m
# 8.	Standard deviation of Canopy cover. 

# 6. CHM standard deviation
sdchm <- aggregate(chm_ext, 10, fun=sd, na.rm=TRUE) # 10 = number of cell vert. and horz. to aggregate
plot(sdchm, col = col)
names(sdchm)<-'sdchm'

mask_ext[is.na(values(sdchm))]=NA
values(sdchm)[is.na(values(sdchm))] = 0 #if no points 

# writeRaster(sdchm, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/sdchm.tif", overwrite=TRUE)


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

myM <- pixel_metrics(nlas, ~myMetrics(Z, ReturnNumber), res = 5) 
plot(myM, col = height.colors(50))  
#values(myM)[is.na(values(myM))] = 0

#writeRaster(myM, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/myM.tif", overwrite=TRUE)


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

CC_1m <- pixel_metrics(nlas, ~myMetrics_1m(Z, ReturnNumber), res = 0.5)
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
values(myM_ext)[is.na(values(myM_ext))]=0

sdCC_crop <- crop(sdCC, myExt, snap="near", extend=FALSE)
sdCC_ext <-extend(sdCC_crop, myExt, fill=NA)
values(sdCC_ext)[is.na(values(sdCC_ext))]=0

## Put everything together (SpatRaster and table)
params_spat <- c(myM_ext, sdCC_ext, sdchm)
params_frame<-data.frame(params_spat)
data <- params_frame[, c(1,2,3,4,5,6,7,8)]


## Write outputs ##
writeRaster(params_spat, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/_params/2577600_1261400_params.tif", overwrite=TRUE)
plot(params_spat, col=col, nc=4,cex.main = 1.5)

values(mask_ext)[is.na(values(mask_ext))]=10000
writeRaster(mask_ext, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/_mask/2577600_1261400_mask.tif", overwrite=TRUE)

