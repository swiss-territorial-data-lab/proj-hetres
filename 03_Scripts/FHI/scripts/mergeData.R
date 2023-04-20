#> This script merges several types of descriptors (structural parameters, NDVI
#> and VHI indices, RGBNIR stats) and join results on the ground truth which has 
#> the health class (10-health, 20-declining, 30-dead) in attribute.
#> 
#> INPUTS:
#> - GT shape with NDVI diff, VHI and health state values. 
#> - mosaic_seg_params.shp : polygons of the segmentation with structural parameters.
#> - mosaic_params.tif : raster with the structural parameters.
#> - mosaic_agl.tif : raster of AGL (understory) 
#> - beech_stats.csv : CSV with statistics (min, max, mean, median, std) and PCA
#>                     components for RGB-NIR and NDVI from aerial imagery. 
#> 
#> OUTPUTS: 
#> - all_desc.csv : CSV where each row is a tree of the ground truth with health 
#>                  state and health descriptors. 


library(config)
library(sf)
library(terra)
library(randomForest)
library(splitTools)
library(caret)
library(varImp)
library(corrplot)
library(Metrics)
library(DeltaMAN)

source("C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/scripts/functions.R")



### Define simulation parameters ###
Sys.setenv(R_CONFIG_ACTIVE = "production")
config <- config::get(file="C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/scripts/config.yml")

SIM_DIR <- config$SIM_DIR
SIM_FOLDER <- config$SIM_FOLDER
SIM_STATS <- config$SIM_STATS_DIR
PATH_GT <- config$PATH_GT



### Link GT & parameters ###
GT <- st_read(PATH_GT)


## Structural params on segmentation shapes
seg_params <- st_read(paste0(SIM_DIR,"mosaic_seg_params.shp"))
seg_params <- seg_params[,-c(1)]
st_crs(seg_params) = st_crs(GT)
seg_params$segID <- seq.int(nrow(seg_params)) 
GT_params<-st_join(GT, seg_params, left=FALSE, right=FALSE)
GT_params <- GT_params[!duplicated(GT_params$NO_ARBRE),]


## Structural params on grid
ras_params <- rast(paste0(SIM_DIR, "mosaic_params.tif"))
GT_params <- extract(ras_params, GT_params, fun=NULL, method="simple", cells=FALSE, xy=FALSE, ID=TRUE, weights=FALSE, exact=FALSE, layer=NULL, bind=TRUE, raw=FALSE)

# with AGL 
agl <- rast(paste0(SIM_DIR,"mosaic_agl.tif"))
zonal_val <- extract(agl,GT_params, as.raster=FALSE, as.polygons=TRUE)
names(zonal_val)<-c("ID","agl")
zonal_val[is.na(zonal_val)]=0
zonal_val <- zonal_val[-c(1)]
GT_params <-as.data.frame(GT_params)
GT_params <-cbind(GT_params,zonal_val)


## Stats and PCA coordinates from aerial imagery
image_params <- read.csv(paste0(SIM_STATS,"beech_stats.csv"))
image_params$no_arbre <- as.numeric(image_params$no_arbre)

blue_b <- image_params[image_params$band=="bleu",][,-c(1,8,9)]
names(blue_b) = c("b_min","b_max","b_mean","b_std", "b_median","no_arbre")
blue_b <- blue_b[!duplicated(blue_b$no_arbre),]
GT_params<-merge(GT_params,blue_b, by.x = "NO_ARBRE", by.y = "no_arbre")

red_b <- image_params[image_params$band=="rouge",][,-c(1,8,9)]
names(red_b) = c("r_min","r_max","r_mean","r_std", "r_median","no_arbre")
red_b <- red_b[!duplicated(red_b$no_arbre),]
GT_params<-merge(GT_params,red_b, by.x = "NO_ARBRE", by.y = "no_arbre", all=FALSE)

green_b <- image_params[image_params$band=="vert",][,-c(1,8,9)]
names(green_b) = c("g_min","g_max","g_mean","g_std", "g_median","no_arbre")
green_b <- green_b[!duplicated(green_b$no_arbre),]
GT_params<-merge(GT_params,green_b, by.x = "NO_ARBRE", by.y = "no_arbre")

nir_b <- image_params[image_params$band=="proche IR",][,-c(1,8,9)]
names(nir_b) = c("nir_min","nir_max","nir_mean","nir_std", "nir_median","no_arbre")
nir_b <- nir_b[!duplicated(nir_b$no_arbre),]
GT_params<-merge(GT_params,nir_b, by.x = "NO_ARBRE", by.y = "no_arbre")

ndvi_b <- image_params[image_params$band=="ndvi",][,-c(1,8,9)]
names(ndvi_b) = c("ndvi_min","ndvi_max","ndvi_mean","ndvi_std", "ndvi_median","no_arbre")
ndvi_b <- ndvi_b[!duplicated(ndvi_b$no_arbre),]
GT_params<-merge(GT_params,ndvi_b, by.x = "NO_ARBRE", by.y = "no_arbre")

pca_ir <- read.csv(paste0(SIM_STATS,"PCA_beeches_proche IR_band_values.csv")) 
pca_ir <- pca_ir[,-c(6)]
names(pca_ir) = c("PC1_nir","PC2_nir","PC3_nir","PC4_nir", "PC5_nir","id")
pca_ir<- pca_ir[!duplicated(pca_ir$id),]
GT_params<-merge(GT_params,pca_ir, by.x = "NO_ARBRE", by.y = "id")

pca_blue <- read.csv(paste0(SIM_STATS,"PCA_beeches_bleu_band_values.csv")) # pc1
pca_blue <- pca_blue[,-c(6)]
names(pca_blue) = c("PC1_b","PC2_b","PC3_b","PC4_b", "PC5_b","id")
pca_blue <- pca_blue[!duplicated(pca_blue$id),]
GT_params<-merge(GT_params,pca_blue, by.x = "NO_ARBRE", by.y = "id")

pca_ndvi <- read.csv(paste0(SIM_STATS,"PCA_beeches_ndvi_band_values.csv")) # pc1 and pc2
pca_ndvi <- pca_ndvi[,-c(6)]
names(pca_ndvi) = c("PC1_ndvi","PC2_ndvi","PC3_ndvi","PC4_ndvi", "PC5_ndvi","id")
pca_ndvi <- pca_ndvi[!duplicated(pca_ndvi$id),]
GT_params<-merge(GT_params,pca_ndvi, by.x = "NO_ARBRE", by.y = "id")


## Final dataframe with all parameters
mydata<-as.data.frame(GT_params)



### Dataset for Random Forest ###

## Choose descriptors ##

# all descriptors
data<-mydata[,c(1,6,11,12,9,8,10,13,7,14:20,46:52,61:104)]
write.csv(data, paste0(SIM_DIR,"all_desc.csv"),row.names=FALSE)