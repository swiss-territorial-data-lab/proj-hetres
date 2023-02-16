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

#### Link GT & parameters ####

myshp <- vect("C:/Users/cmarmy/Documents/STDL/Beeches/GT/GT_Z_beechesAOI_corr_attribute_poly.shp")

myras<-rast("C:/Users/cmarmy/Documents/STDL/Beeches/FHI/mosaic.tif")

zonal_val <- zonal(myras,myshp, as.raster=FALSE, as.polygons=TRUE)
names(zonal_val)<-c("zq99","alpha","beta","cvLAD","VCI","CC","sdCC","sdchm")
zonal_val$row_num <- seq.int(nrow(zonal_val)) 
myshp_zonal <- merge(myshp,zonal_val, all.x=TRUE, by.x=c('fid'), by.y=c('row_num'))

writeVector(myshp_zonal, "C:/Users/cmarmy/Documents/STDL/Beeches/FHI/GT_Z_beechesAOI_corr_attribute_poly_zonal.shp", filetype=NULL, layer=NULL, insert=FALSE,overwrite=TRUE, options="ENCODING=UTF-8")

## Plot Health state vs. parameters
plot(myshp_zonal$class_san3,myshp_zonal$zq99)
plot(myshp_zonal$class_san3,myshp_zonal$alpha)
plot(myshp_zonal$class_san3,myshp_zonal$beta)
plot(myshp_zonal$class_san3,myshp_zonal$cvLAD)
plot(myshp_zonal$class_san3,myshp_zonal$VCI)
plot(myshp_zonal$class_san3,myshp_zonal$CC)
plot(myshp_zonal$class_san3,myshp_zonal$sdCC)
plot(myshp_zonal$class_san3,myshp_zonal$sdchm)



### HIERARCHICAL CLUSTERING - PEARSON'S CORRELATION ###

data<-zonal_val
res <- cor(data, method='pearson')

corrplot.mixed(res, order = 'AOE', tl.srt = 45, tl.col = "black", lower.col = "black")
# IN : c("1.zq99","2.alpha","3.beta","4.cvLAD","5.VCI","6.CC","7.sdCC","8.sdchm")
# RES : zq99, cvLAD, (VCI,alpha,beta), CC, (sdCC,sdchm) 

## Choose significant parameters
data_slc = data[, c(1,4,5,6,8)]



## HIERARCHICAL CLUSTERING - THRESHOLDS IN THREE CLASSES ##
dist_slc<-dist(data_slc, method = "euclidean", diag = FALSE, upper = FALSE, p = 2) # which method ? "euclidean", "maximum", "manhattan", "canberra", "binary" or "minkowski"

hclust_slc<-hclust(dist_slc, method = "ward.D2", members = NULL) # which method ?  "ward.D", "ward.D2", "single", "complete", "average" (= UPGMA), "mcquitty" (= WPGMA), "median" (= WPGMC) or "centroid" (= UPGMC).

hclust_slc_cut <- cutree(hclust_slc, k = 3)

plot(hclust_slc, labels = NULL, hang = 0.1, check = TRUE,
     axes = TRUE, frame.plot = FALSE, ann = TRUE,
     main = names(data_slc),
     sub = NULL, xlab = NULL, ylab = "Height")


thd<-matrix(, nrow = length(data_slc), ncol = 3)
for (l in 1:length(data_slc)){
  
  dist_slc<-dist(data_slc[l], method = "euclidean", diag = FALSE, upper = FALSE, p = 2) # which method ? "euclidean", "maximum", "manhattan", "canberra", "binary" or "minkowski"
  
  hclust_slc<-hclust(dist_slc, method = "ward.D", members = NULL) # which method ?  "ward.D", "ward.D2", "single", "complete", "average" (= UPGMA), "mcquitty" (= WPGMA), "median" (= WPGMC) or "centroid" (= UPGMC).
  
  hclust_slc_cut <- cutree(hclust_slc, k = 3)
  
  plot(hclust_slc, labels = NULL, hang = 0.1, check = TRUE,
       axes = TRUE, frame.plot = FALSE, ann = TRUE,
       main = names(data_slc)[l],
       sub = NULL, xlab = NULL, ylab = "Height")
  
  # Idendify threshold
  data_slc_vec <- unlist(data_slc[l])
  
  thd_fuzzy=c()
  k=0
  for (i in 1:3){
    thd_fuzzy[k]<-min(data_slc_vec[hclust_slc_cut==i])
    thd_fuzzy[k+1]<-max(data_slc_vec[hclust_slc_cut==i])
    k=k+2
  }
  thd_sort<-sort(thd_fuzzy)
  thd[l,1] <- names(data_slc)[l]
  thd[l,2] <-(thd_sort[2]+thd_sort[3])/2
  thd[l,3] <-(thd_sort[4]+thd_sort[5])/2
}
thd



### CLASSIFICATION ###

## Thresholds on parameters
#         Class H1 | Class SH2 | Class U3
# param |
# param |
# param |
# param |
# param |

#params_spat c("1.zq99","2.alpha","3.beta","4.cvLAD","5.VCI","6.CC","7.sdCC","8.sdchm")
thd_pos <- thd[] #zq99, cvLAD
thd_pos<-t(thd_pos)
thd_neg <- thd[] #sdchm, mVCI, CC, sdCC
thd_neg<-t(thd_neg)
slc_neg = c(1,6,7,8)
slc_pos = c(2,5)

params_spat_cat <- params_spat
for (l in 1:4){ # !! attention au sens des treshold selon les paramètres.
  values(params_spat_cat)[,slc_neg[l]][values(params_spat)[,slc_neg[l]]>thd_neg[l,2]] = 3
  values(params_spat_cat)[,slc_neg[l]][values(params_spat)[,slc_neg[l]]<=thd_neg[l,2] & values(params_spat)[,slc_neg[l]]>=thd_neg[l,1]] = 2
  values(params_spat_cat)[,slc_neg[l]][values(params_spat)[,slc_neg[l]]<thd_neg[l,1]] = 1
}

for (l in 1:2){ # !! attention au sens des treshold selon les paramètres.
  values(params_spat_cat)[,slc_pos[l]][values(params_spat)[,slc_pos[l]]<thd_pos[l,2]] = 3
  values(params_spat_cat)[,slc_pos[l]][values(params_spat)[,slc_pos[l]]>=thd_pos[l,2] & values(params_spat)[,slc_pos[l]]<=thd_pos[l,1]] = 2
  values(params_spat_cat)[,slc_pos[l]][values(params_spat)[,slc_pos[l]]>thd_pos[l,1]] = 1
}

writeRaster(params_spat_cat, "C:/Users/cmarmy/Desktop/test/params_spat_thd.tif", overwrite=TRUE)


## Health categories
# Healthy (H-1) Three or more indicators are Class 1 and not Class 3. 
# Subhealthy (S-2) Two or less indicators are Class 1. 
# Unhealthy (U-3) All indicators are Class 2 or Class 3 and not Class 1.

health_map <- sdchm
for (l in 1:900){
  
  if (sum(values(params_spat_cat)[l,][values(params_spat_cat)[l,]==1])>3 & sum(values(params_spat_cat)[l,][values(params_spat_cat)[l,]==3])==0){
    health_map[l] = 1
  } else if (sum(values(params_spat_cat)[l,][values(params_spat_cat)[l,]==1])==0){
    health_map[l] = 3
  } else{
    health_map[l] = 2
  }
}

writeRaster(health_map, "C:/Users/cmarmy/Desktop/test/health_map.tif", overwrite=TRUE)



#### Comparer les pixels avec les points de la vérité terrain ####
myRas <-rast("C:/Users/cmarmy/Desktop/test/health_map.tif")
mySHP<- st_read("C:/Users/cmarmy/Documents/STDL/Beeches/GT/GT_Z_beechesAOI_corr_attribute.shp")
rasValue=extract(myRas, mySHP)
combinePointValue=cbind(mySHP,rasValue)
combinePointValue$focal_mean[is.na(combinePointValue$focal_mean)]=0
#write.table(combinePointValue,file='combinedPointValue.csv', append=FALSE, sep= ',', row.names = FALSE, col.names=TRUE)combinePointValue$class_san3

#Creating confusion matrix
example <- confusionMatrix(data=combinePointValue$focal_mean, reference = combinePointValue$class_san3)
table(expected_value,predicted_value)

