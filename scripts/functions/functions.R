#> List of functions:
#> - metricsParams: compute customized metrics per pixel. 
#> - metricsParams1m: compute customized metrics per pixel. The pixel are 10-times
#>                     smaller than in metricsParams.
#> - crownMetricsParams: compute customized metrics per segmentation polygons. 
#> - mergeRaster: merge the raster files produced in FHI_catalog.R into a mosaic.
#> - mergeVector: merge the shape files produced in FHI_catalog.R into a mosaic.
#> - mergeVectors: merge the segmented trees and the peaks of all the files produced 
#>              by FHI_catalog.R into two files for segments and peaks. 
#>              Only keep peeks corresponding to a segment.
#> - mySummary: customized summary function: 1. minimizing unhealthy->healthy, 
#>              dead->healthy and dead->unhealthy, 2. computing linear weighted 
#>              kappa. 


### STRUCTURAL PARAMETERS ###

# 1.	99 percentile height.
# 2.	Two parameters Weibull-density.
# 3.  Two parameters Weibull-density.
# 4.	Coefficient of Variation of Leaf Area Density.
# 5.	Vertical Complexity Index.
# 6.	CHM standard deviation.
# 7.  Canopy Cover.
# 8.	Standard deviation of Canopy cover.


metricsParams <- function(z,rn,intnst) {
  
  # for 2., 3. 4 and 5.
  dz <- 1
  zmax <- 42
  h <- zmax-min(z)
  n <- h/dz  # number of elevation level
  
  if (h<2){ # when vegetation is too low, parameters set to null
    cc=0
  } else {
    
    # 2. & 3. Weibull's scale and shape parameters
    hp = h/10 # height percentiles
    chp <- vector() # point density per height percentiles
    for (k in 1:10){
      chp[k] <- sum(z>=hp*(k-1) & z<hp*k)/sum(z>=0)
      if (sum(z>=0)==0){
        chp[k]=0
      }
    }
    
    # interpolate if chp==0
    for (k in 2:9){
      if (chp[k] == 0) {
        chp[k] = abs(chp[k+1]+chp[k-1])/2
      }
    }
    if (chp[1] == 0){
      chp[1] = chp[2]/2
    }
    if (chp[10] == 0){
      chp[10] = chp[9]/2
    }
    
    if (sum(chp==0)>=3){
      alpha = 0
      beta = 0
    }else{
      wb <- eweibull(chp, method = "mle")
      alpha <- wb[["parameters"]][["scale"]]
      beta <- wb[["parameters"]][["shape"]]
    }
    
    
    # 4. Coeffient of vertical Lear Area Density
    KAPPA <- 0.67 # see literature
    gf <- vector()
    ladh <- vector()
    for (i in 1:n){
      if ((sum(z<dz*(i-1) & z>=0)<=0) || (sum(z>dz*i)<=0)){
        gf[i]=0
        ladh[i]=NA
      }else{
        gf[i] <- (sum(z<dz*(i-1) & z>=0))/(as.double(sum(z>=0))*as.double(sum(z>dz*i))) 
        ladh[i] = -log(gf[i])/KAPPA*dz
      }
    }
    
    cvlad <- sqrt(1/((n-sum(is.na(ladh)))-1)*sum((ladh-mean(ladh,na.rm=T))^2,na.rm=T))/mean(ladh,na.rm=T) # ?? changer n si des lad ont une valeur nulle ?
    
    
    # 5. Vertical Complexity Index
    p <- vector()
    for (k in 1:n){
      if (sum(z>=dz*(k-1)&z<dz*k)<=0){
        p[k] <- NA
      }else{
        p[k] <- (sum(z>=dz*(k-1)&z<dz*k))/sum(z>=0)  
      }
    }
    
    vci=-sum(p*log(p), na.rm = TRUE)/log(n-sum(is.na(p)))
    
    
    # 7. Canopy Cover
    first  = rn == 1L
    zfirst = z[first]
    nfirst = length(zfirst)
    firstabove2 = sum(zfirst > 2)
    x = (firstabove2/nfirst)*100
    
    cc <- (firstabove2/nfirst)*100 # no first is possible, if in filtered classes
  }
  
  metrics <- list(
    zq99=stats::quantile(z[z>2], 0.99),
    alpha=alpha,
    beta=beta,
    cvlad=cvlad,
    vci=vci,
    i_mean=as.double(stats::median(intnst[z>(max(z)/2)])),
    i_sd = as.double(stats::sd(intnst[z>(max(z)/2)])),
    cc = cc
  )
  
  return(c(metrics))
}


metricsParams1m <- function(z, rn)
{
  # 7-8. Canopy Cover for standard deviation computation
  first  = rn == 1L 
  zfirst = z[first]
  nfirst = length(zfirst)
  firstabove2 = sum(zfirst > 2)
  x = (firstabove2/nfirst)*100
  
  cc <- (firstabove2/nfirst)*100 # no first is possible, if in filtered classes
  
  metrics <- list(
    sdcc = cc
  )
  
  return(c(metrics))
}

crownMetricsParams <- function(z,label,rn,intnst) {
  
  # for 2., 3. 4 and 5.
  dz <- 1
  zmax <- 42
  h <- zmax-min(z)
  n <- h/dz  # number of elevation level
  
  if (h<2){ # when vegetation is too low, parameters set to null
    alpha=0
    beta=0
    cvlad=0
    vci=0
  } else {
    
    # 2. & 3. Weibull's scale and shape parameters
    hp = h/10 # height percentiles
    chp <- vector() # point density per height percentiles
    for (k in 1:10){
      chp[k] <- sum(z>=hp*(k-1) & z<hp*k)/sum(z>=0)
      if (sum(z>=0)==0){
        chp[k]=0
      }
    }
    
    # interpolate if chp==0
    for (k in 2:9){
      if (chp[k] == 0) {
        chp[k] = abs(chp[k+1]+chp[k-1])/2
      }
    }
    if (chp[1] == 0){
      chp[1] = chp[2]/2
    }
    if (chp[10] == 0){
      chp[10] = chp[9]/2
    }
    
    if (sum(chp==0)>=3){
      alpha = 0
      beta = 0
    }else{
      wb <- eweibull(chp, method = "mle")
      alpha <- wb[["parameters"]][["scale"]]
      beta <- wb[["parameters"]][["shape"]]
    }
    
    
    # 4. Coeffient of vertical Lear Area Density
    KAPPA <- 0.67 # see literature
    gf <- vector()
    ladh <- vector()
    for (i in 1:n){
      if ((sum(z<dz*(i-1) & z>=0)<=0) || (sum(z>dz*i)<=0)){
        gf[i]=0
        ladh[i]=NA
      }else{
        gf[i] <- (sum(z<dz*(i-1) & z>=0))/(as.double(sum(z>=0))*as.double(sum(z>dz*i))) 
        ladh[i] = -log(gf[i])/KAPPA*dz
      }
    }
    
    cvlad <- sqrt(1/((n-sum(is.na(ladh)))-1)*sum((ladh-mean(ladh,na.rm=T))^2,na.rm=T))/mean(ladh,na.rm=T) # ?? changer n si des lad ont une valeur nulle ?
    
    
    # 5. Vertical Complexity Index
    p <- vector()
    for (k in 1:n){
      if (sum(z>=dz*(k-1)&z<dz*k)<=0){
        p[k] <- NA
      }else{
        p[k] <- (sum(z>=dz*(k-1)&z<dz*k))/sum(z>=0)  
      }
    }
    
    vci=-sum(p*log(p), na.rm = TRUE)/log(n-sum(is.na(p)))
    
  }
  
  metrics <- list(
    zq99_seg=stats::quantile(z[z>2], 0.99),
    alpha_seg=alpha,
    beta_seg=beta,
    cvlad_seg=cvlad,
    vci_seg=vci,
    i_mean_seg=as.double(stats::median(intnst[z>(max(z)/2)])),
    i_sd_seg = as.double(stats::sd(intnst[z>(max(z)/2)]))
  )
  
  return(metrics)
}


mergeRaster<-function(wkdir, extension, func, output){
  files <- list.files(path=wkdir, pattern=extension, full.names=TRUE, recursive=FALSE)
  
  r0 <- rast(files[1])
  for (f in files){
    r <- rast(f)
    rlist <- list(r0,r)
    rsrc <- sprc(rlist)
    r0 <- mosaic(rsrc,fun=func)
  }

  writeRaster(r0, paste0(wkdir,output), overwrite=TRUE)
}


mergeVector<-function(wkdir, extension, output){
  files <- list.files(path=wkdir, pattern=extension, full.names=TRUE, recursive=FALSE)
  
  r0 <- data.frame()
  for (i in 1:length(files)){
    
    r <- as.data.frame(st_read(files[i]))
    
    r0<-rbind(r0,r)
  }
  r0$segID <- seq.int(nrow(r0)) 
  r0 <- r0[,-c(1)]
  
  file.remove(paste0(SIM_DIR,output))
  st_write(r0, paste0(SIM_DIR,output))
}


mergeVectors<-function(datadir, datadir2, extension, extension2, output, output2){
  files <- list.files(path=datadir, pattern=extension, full.names=TRUE, recursive=FALSE)
  files2 <- list.files(path=datadir2, pattern=extension2, full.names=TRUE, recursive=FALSE) 

  r0 <- data.frame()
  q0 <-data.frame()
  for (i in 1:length(files)){

    r <- as.data.frame(st_read(files[i]))
    q <- as.data.frame(st_read(files2[i]))
    q <- q[,c(2,9)]
    
    ind <- is.element(q[,c(1)],r[,c(1)])
    
    r0<-rbind(r0,r)
    q0<-rbind(q0,q[ind,])
  }
  r0$segID <- seq.int(nrow(r0)) 
  q0$segID <- seq.int(nrow(q0)) 
  r0 <- r0[,-c(1)]
  q0 <- q0[,-c(1)]

  file.remove(paste0(SIM_DIR,output))
  st_write(r0, paste0(SIM_DIR,output))
  file.remove(paste0(SIM_DIR,output2))
  st_write(q0, paste0(SIM_DIR,output2))
}

mySummary <- function(data, lev=NULL, model=NULL){
  cf <- confusionMatrix(data$obs, data$pred)
  fdr <- (cf[["table"]][1,2] + cf[["table"]][1,3] + cf[["table"]][2,3]) / sum(cf[["table"]][,2:3]) # false detection rate
  wgthd_kappa <- as.numeric(Kappa(cf[["table"]], r = 1, alternative = c("two.sided"), conf.level = 0.95, partial = FALSE)[1])
  customizedAccuracy <-  c(fdr, wgthd_kappa[1])
  names(customizedAccuracy) <- c("fdr","wgthd_kappa")
  return(customizedAccuracy)
}
