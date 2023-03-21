#> List of functions
#> metricsParams
#> metricsParams1m
#> crownMetricsParams
#> mergeRaster
#> mergeVector


metricsParams <- function(z, rn) {
  
  ### STRUCTURAL PARAMETERS ###
  
  # 1.	99 percentile height.
  # 2.	Two parameters Weibull-density.
  # 3.  Two parameters Weibull-density.
  # 4.	Coefficient of Variation of Leaf Area Density.
  # 5.	Vertical Complexity Index.
  # 6.	CHM standard deviation.
  # 7.  Canopy Cover.
  # 8.	Standard deviation of Canopy cover.
  
  
  # for 2., 3. and 4.
  dz <- 1 # thickness of the elevation level
  h <- max(z)-min(z) # max(z[z>2])-min(z[z>2])
  n <- ceiling(h)/dz  # number of elevation level
  
  if (h<2){ # in case of low vegetation only
    alpha=0
    beta=0
    cvlad=0
    mvci=0
    cc = 0
  } else {
    
    #2. Weibull's scale and shape parameters
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
    
    
    ## 3. Two parameters Weibull-density
    KAPPA <- 0.67 # Bréda, N.J. Ground-based measurements of leaf area index: a review of methods, instruments and current controversies. J. Exp. Bot. 2003, 54, 2403–2417.
    gf <- vector()
    ladh <- vector()
    # gf[1] <- 1/((sum(z>0)+1)*sum(z>dz)) # +1, at least one point in layer
    # ladh[1] = -log(gf[1])/KAPPA*dz
    for (i in 1:n){
      gf[i] <- (sum(z<dz*(i-1) & z>=0)+1)/((sum(z>=0)+2)*(sum(z>dz*i)+1)) # +1, at least one point in layer
      ladh[i] = -log(gf[i])/KAPPA*dz
    }
    
    cvlad <- sqrt(1/(n-1)*sum((ladh-mean(ladh))^2))/mean(ladh)
    
    
    # 4. Vertical Complexity Index
    p <- vector()
    for (k in 1:n){
      p[k] <- (sum(z>=dz*(k-1)&z<dz*k)+1)/(sum(z>=0)+1) # +1, at least one point in layer
    }
    
    mvci <- -dot(p,log(p))/log(n) #VCI(nlas@data$Z, 30, by = 1)
    
    
    # 6.
    first  = rn == 1L
    zfirst = z[first]
    nfirst = length(zfirst)
    firstabove2 = sum(zfirst > 2)
    x = (firstabove2/nfirst)*100
    
    cc <- (firstabove2/nfirst)*100 # no first is possible, if in filtered classes
    
    if (is.infinite(cc)){
      browser()
    }
  }
  
  metrics <- list(
    zq99=stats::quantile(z[z>2], 0.99),
    alpha=alpha,
    beta=beta,
    cvlad=cvlad,
    mvci=mvci,
    # sdCHM = done on smoothed chm
    cc = cc
    # sdcc = do it afterward on cc 
  )
  
  return(c(metrics))
}

metricsParams1m <- function(z, rn)
{
  # 6.
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
  
  ### STRUCTURAL PARAMETERS ###
  # 2.	Two parameters Weibull-density.
  # 3.  Two parameters Weibull-density.
  # 4.	Coefficient of Variation of Leaf Area Density.
  # 5.	Vertical Complexity Index.
  # 7.  Canopy Cover.
  
  # for 2., 3. and 4.
  dz <- 5 # thickness of the elevation level
  zmax <- max(z)
  h <- zmax-min(z)
  n <- floor(h)/dz  # number of elevation level
  
  if (h<2){ # when vegetation is too low, parameters set to null
    alpha=0
    beta=0
    cvLAD=0
    mVCI=0
    CC = 0
  } else {
    
    # 2. Weibull's scale and shape parameters
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
    
    
    # 4.
    kappa <- 0.67 # see literature
    GF <- vector()
    LADh <- vector()
    for (i in 1:n){
      GF[i] <- (sum(z<dz*(i-1) & z>=0)+1)/((sum(z>=0)+2)*(sum(z>dz*i)+1)) # +1, at least one point in layer
      LADh[i] = -log(GF[i])/kappa*dz
    }
    
    cvLAD <- sqrt(1/(n-1)*sum((LADh-mean(LADh))^2))/mean(LADh)
    
    
    # 5. Vertical Complexity Index
    P <- vector()
    for (k in 1:n){
      P[k] <- (sum(z>=dz*(k-1)&z<dz*k)+1)/(sum(z>=0)+1) # +1, at least one point 
      # in layer
    }
    
    mVCI <- -dot(P,log(P))/log(n)
    
    
    # 7.
    first  = rn == 1L
    zfirst = z[first]
    nfirst = length(zfirst)
    firstabove2 = sum(zfirst > 2)
    x = (firstabove2/nfirst)*100
    
    CC <- (firstabove2/nfirst)*100 # no first is possible, if in filtered classes
    # when loading classified point cloud
  }
  
  metrics <- list(
    zq99=stats::quantile(z[z>2], 0.99),
    alpha=alpha,
    beta=beta,
    cvLAD=cvLAD,
    mVCI=mVCI,
    # sdCHM = done on smoothed chm
    CC = CC,
    # sdCC = done afterward on CC 
    i_mean=as.double(stats::median(intnst[z>(zmax/2)])),
    i_std = as.double(stats::sd(intnst[z>(zmax/2)]))
  )
  
  return(metrics)
}

mergeRaster<-function(wkdir, extension, output){
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

mergeVector<-function(wkdir, extension, output){
  files <- list.files(path=wkdir, pattern=extension, full.names=TRUE, recursive=FALSE)
  
  r0 <- as.data.frame(st_read(files[1]))
  for (f in files){
    r <- as.data.frame(st_read(f))
    r <- r[-1,]
    r0<-rbind(r0,r)
  }
  
  file.remove(paste0(SIM_DIR,output))
  st_write(r0, paste0(SIM_DIR,output))
}
