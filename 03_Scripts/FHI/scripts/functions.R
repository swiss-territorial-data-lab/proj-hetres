#> List of functions
#> metricsParams
#> metricsParams1m
#> mergeRaster


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
  n <- ceil(h)/dz  # number of elevation level
  
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
