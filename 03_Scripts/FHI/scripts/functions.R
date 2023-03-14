myMetrics <- function(z, rn) {
  # for 2., 3. and 4.
  dz <- 5 # thickness of the elevation level
  h <- max(z)-min(z) # max(z[z>2])-min(z[z>2])
  n <- floor(h)/dz  # number of elevation level
  
  if (h<2){ #if vegetation too low, then make it higher ?
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
    
    
    ## 3. Two parameters Weibull-density
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
    
    if (is.infinite(CC)){
      browser()
    }
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
