library(raster)
library(pracma)
library(EnvStats)
library(corrplot)
library(Hmisc)
library(dendextend)
library(lidR)
# Caution: cutree in dendextend masked

# --- Questions --- #
# ?? Catalog engine, demandera un certain effort. Par exemple, filter_poi can not be used on ctg object ??
# ?? Does it make sens to define threshold with clustering on one varialbes ? 


# --- Remarques --- #
# GF, LAD and VCI from package not use, because not directly usable in pixel_metrics
# le fait d'ajouter un point quand il n'y en a pas.
# Gestion des Inf, mis à NaN puis filled by mean. 




### Load LAS files ###

# ctg <- readLAScatalog("C:/Users/cmarmy/Documents/STDL/Beeches/DFT/data/sample/", select = "xyzc")
ctg <- readLAS("C:/Users/cmarmy/Documents/STDL/Beeches/DFT/data/sample/sampleMIE.las")
# plot(ctg, size = 3, map = TRUE)

ctg = filter_poi(ctg, Classification >= 2 & Classification <=5 )



### Normalized point cloud ###

## with ground points
nlas <- normalize_height(ctg, knnidw())
#plot(ctg, size = 3, map = TRUE) 
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
chm <- rasterize_canopy(nlas, res=1, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smooting 

writeRaster(chm, "C:/Users/cmarmy/Desktop/test/chm.tif", overwrite=TRUE)

fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(mean(x, na.rm = TRUE)) } else { return(x[i]) }}
w <- matrix(1, 3, 3)

chm_filled <- terra::focal(chm, w, fun = fill.na)
chm_smoothed <- terra::focal(chm_filled, w, fun = mean, na.rm = TRUE)

chms <- c(chm, chm_filled, chm_smoothed)
names(chms) <- c("Base", "Filled", "Smoothed")
col <- height.colors(25)
plot(chms, col = col)

writeRaster(chm_smoothed, "C:/Users/cmarmy/Desktop/test/chm_smoothed.tif", overwrite=TRUE)


## AGL (Above Ground Level)
agl <- rasterize_canopy(filter_poi(nlas, Z >= 0.5 & Z <=10 ), res=1, pitfree(thresholds = c(0, 10, 20, 30), max_edge = c(0, 1.5), subcircle = 0.15)) # adjust max_edge for smooting 
col <- height.colors(25)
plot(agl, col = col)

writeRaster(agl, "C:/Users/cmarmy/Desktop/test/agl.tif", overwrite=TRUE)



### STRUCTURAL PARAMETERS ###

# 1.	99 percentile height.
# 2.	Two parameter Weibull-density. 
# 3.	Coefficient of Variation of Leaf Area Density. 
# 4.	Vertical Complexity Index. 
# 5.	CHM standard deviation. 
# 6.	Standard deviation of Canopy cover. 

# 5. CHM standard deviation
sdchm <- aggregate(chm_smoothed, 10, fun=sd) # 10 = number of cell vert. and horz. to aggregate
plot(sdchm, col = col)


myMetrics <- function(z, rn)
{
  # for 2., 3. and 4.
  dz <- 1 # thickness of the elevation level
  h <- max(z)-min(z) # max(z[z>2])-min(z[z>2])
  n <- floor(h)/dz  # number of elevation level
  
  
  #2. Weibull's scale and shape parameters
  hp = h/10 # height percentiles
  CHP <- vector() # point density per height percentiles
  for (k in 1:10){
    CHP[k] <- sum(z>hp*(k-1) & z<=hp*k)/sum(z>0)
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
  
  wb <- eweibull(CHP, method = "mle")
  alpha <- wb[["parameters"]][["scale"]]
  beta <- wb[["parameters"]][["shape"]]
  
  
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

myM <- pixel_metrics(nlas, ~myMetrics(Z, ReturnNumber), res = 10) 
plot(myM, col = height.colors(50))  

writeRaster(myM, "C:/Users/cmarmy/Desktop/test/myM.tif", overwrite=TRUE)


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

CC_1m <- pixel_metrics(nlas, ~myMetrics_1m(Z, ReturnNumber), res = 1)
plot(CC_1m,col=col)

fill.na <- function(x, i=5) { if (is.na(x)[i]) { return(0) } else { return(x[i]) }}
w <- matrix(1, 3, 3)
CC_1m_filled <- terra::focal(CC_1m, w, fun = fill.na)
plot(CC_1m_filled, col = col)

writeRaster(CC_1m_filled, "C:/Users/cmarmy/Desktop/test/CC_1m_filled.tif", overwrite=TRUE)

sdCC <- aggregate(CC_1m_filled[[1]], 10, fun=sd, na.action=1)
plot(sdCC, col = col)


## Put everything together (SpatRaster and table)
params_spat <- c(sdchm, myM, sdCC)
sdchm_frame<-as.data.frame(sdchm)
myM_frame<-as.data.frame(myM)
sdCC_frame<-as.data.frame(sdCC)
params_frame<-data.frame(sdchm_frame, myM_frame, sdCC_frame)
data <- params_frame[, c(2,3,4,5,6,7,8)]


#### Ici, il faudra merger tous les LAS en un seul dataframe - FIN du catalog engine ####



### HIERARCHICAL CLUSTERING - PEARSON'S CORRELATION ###

res <- cor(data, method='pearson')

corrplot.mixed(res, order = 'AOE', tl.srt = 45, tl.col = "black", lower.col = "black")
# RES : indépendants cvLAD, zq99, sdCC, CC, (mVCI,alpha,beta)

# Choose significant parameters 
#param1_ = params[, c(1)]
#param2_ = 
#param3_ = 
#param4_ =
#param5_ =
data_slc = data[, c(1,4,5,6)]
slc = c(1,4,5,6)



## HIERARCHICAL CLUSTERING - THRESHOLDS IN THREE CLASSES ##

dist_slc<-dist(data_slc, method = "euclidean", diag = FALSE, upper = FALSE) # which method ?

hclust_slc<-hclust(dist_slc, method = "ward.D", members = NULL) # which method ?

hclust_slc_cut <- cutree(hclust_slc, k = 3)

plot(hclust_slc, labels = NULL, hang = 0.1, check = TRUE,
     axes = TRUE, frame.plot = FALSE, ann = TRUE,
     main = "Cluster Dendrogram",
     sub = NULL, xlab = NULL, ylab = "Height")


# Identify threshold

for (l in 1:5){
  data_slc_vec <- unlist(data_slc[l])
  
  for (i in 1:3){
    print(paste(names(data_slc)[l],i,min(data_slc_vec[hclust_slc_cut==i]),max(data_slc_vec[hclust_slc_cut==i])))
  }
}



### CLASSIFICATION ###

## Thresholds on parameters
#         Class H1 | Class SH2 | Class U3
# param |
# param |
# param |
# param |
# param |

thd <- array(c(c(1,2),c(1,2),c(1,2),c(1,2),c(1,2)),dim=c(5,2))

for (l in 1:5){ # !! attention au sens des treshold selon les paramètres.
  values(params_spat)[,slc[l]][values(params_spat)[,slc[l]]<thd[l,2]] = 3
  values(params_spat)[,slc[l]][values(params_spat)[,slc[l]]>=thd[l,2] & values(params_spat)[,slc[l]]<=thd[l,1]] = 2
  values(params_spat)[,slc[l]][values(params_spat)[,slc[l]]>thd[l,1]] = 1
}


## Health categories
# Healthy (H-1) Three or more indicators are Class 1 and not Class 3. 
# Subhealthy (S-2) Two or less indicators are Class 1. 
# Unhealthy (U-3) All indicators are Class 2 or Class 3 and not Class 1.

health_map <- sdchm
for (l in 1:900){
  if (sum(values(params_spat)[l,][values(params_spat)[l,]==1])>3 & sum(values(params_spat)[l,][values(params_spat)[l,]==3])==0){
    health_map[l] = 3
  }
  #if (sum()<=2) {}
  if (sum(values(params_spat)[l,][values(params_spat)[l,]==1])==0){
    health_map[l] = 1
  }
  else{
    health_map[l] = 2
  }
}

writeRaster(health_map, "C:/Users/cmarmy/Desktop/test/health_map.tif", overwrite=TRUE)
