#> This script merges several types of descriptors (structural parameters, NDVI
#> and RGBNIR stats) and join results on the ground truth which has 
#> the health class (10-health, 20-declining, 30-dead) in attribute.
#> 
#> INPUTS:
#> - GT shape. 
#> - mosaic_seg_params.shp : polygons of the segmentation with structural parameters.
#> - mosaic_params.tif : raster with the structural parameters.
#> - mosaic_agl.tif : raster of AGL (understory) 
#> - beech_stats.csv : CSV with statistics (min, max, mean, median, std) and PCA
#>                     components for RGB-NIR and NDVI from aerial imagery. 
#> 
#> OUTPUTS: 
#> - all_desc.csv : CSV where each row is a tree of the ground truth or of the
#>   segmented trees with health state and health descriptors. 


library(config)
library(sf)
library(terra)



### Define simulation parameters ###
Sys.setenv(R_CONFIG_ACTIVE = "production")
config <- config::get(file="C:/Users/cmarmy/Documents/STDL/Beeches/delivery/scripts/config.yml")

SIM_DIR <- config$SIM_DIR
SIM_FOLDER <- config$SIM_FOLDER
TRAIN <- config$TRAIN_DATA
PATH_GT <- config$PATH_GT
SIM_STATS <- config$SIM_STATS_DIR
NDVI_DIR <- config$NDVI_DIR
OUT_DIR<- config$RF_DIR



### Link response variable & descriptors ###
if (TRAIN) {
  RESP <- st_read(PATH_GT)
  RESP <- RESP[,c("CLASS_SAN3","NO_ARBRE")]
  CSV_NAME <- "all_desc_GT_nohf.csv"
}else {
  RESP <- st_read(paste0(SIM_DIR,"mosaic_peaks.shp"))
  RESP <- RESP[,c("segID","segID")]
  CSV_NAME <- "all_desc_seg_hf.csv" 
}
names(RESP)<-c("CLASS_SAN","ID","geometry")


## Structural params on segmentation shapes
seg_params <- st_read(paste0(SIM_DIR,"mosaic_seg_params.shp"))
st_crs(RESP) <- st_crs(seg_params)

RESP_params<-st_join(RESP, seg_params[,c(1:8)], join=st_intersects,left=FALSE, right=FALSE)
RESP_params<-RESP_params[,c(1:2,10,3:9,11)]
RESP_params <- RESP_params[!duplicated(RESP_params$ID),]


## Structural params on grid
ras_params <- rast(paste0(SIM_DIR, "mosaic_params.tif"))
RESP_params <- extract(ras_params, RESP_params, fun=NULL, method="simple", cells=FALSE, xy=FALSE, ID=TRUE, weights=FALSE, exact=FALSE, layer=NULL, bind=TRUE, raw=FALSE)

# with AGL 
agl <- rast(paste0(SIM_DIR,"mosaic_agl.tif"))
RESP_params <- extract(agl, RESP_params,  fun=mean, method="simple", cells=FALSE, xy=FALSE, ID=TRUE, weights=FALSE, exact=FALSE, layer=NULL, bind=TRUE, raw=FALSE)
names(RESP_params)[21] = "agl"

## NDVI difference from waldmonitoring.ch
ndvi_list = c("wcs_ndvi_diff_2016_2015.tif","wcs_ndvi_diff_2017_2016.tif","wcs_ndvi_diff_2018_2017.tif","wcs_ndvi_diff_2019_2018.tif","wcs_ndvi_diff_2020_2019.tif","wcs_ndvi_diff_2021_2020.tif","wcs_ndvi_diff_2022_2021.tif")
for (el in ndvi_list){
  ndvi <- rast(paste0(NDVI_DIR, el))
  RESP_params <- extract(ndvi, RESP_params, fun=NULL, method="simple", cells=FALSE, xy=FALSE, ID=TRUE, weights=FALSE, exact=FALSE, layer=NULL, bind=TRUE, raw=FALSE)
}
names(RESP_params)[c(22:28)] <- c("NDVI_diff_1615","NDVI_diff_1716","NDVI_diff_1817","NDVI_diff_1918","NDVI_diff_2019","NDVI_diff_2120","NDVI_diff_2221")
RESP_params<-as.data.frame(RESP_params)


## Stats and PCA coordinates from aerial imagery
image_params <- read.csv(paste0(SIM_STATS,"beech_stats.csv"))

blue_b <- image_params[image_params$band=="bleu",][,c(2:7)]
names(blue_b) = c("b_min","b_max","b_mean","b_std", "b_median","id")
blue_b <- blue_b[!duplicated(blue_b$id),]
RESP_params<-merge(RESP_params,blue_b, by.x = "ID", by.y = "id")

red_b <- image_params[image_params$band=="rouge",][,c(2:7)]
names(red_b) = c("r_min","r_max","r_mean","r_std", "r_median","id")
red_b <- red_b[!duplicated(red_b$id),]
RESP_params<-merge(RESP_params,red_b, by.x = "ID", by.y = "id", all=FALSE)

green_b <- image_params[image_params$band=="vert",][,c(2:7)]
names(green_b) = c("g_min","g_max","g_mean","g_std", "g_median","id")
green_b <- green_b[!duplicated(green_b$id),]
RESP_params<-merge(RESP_params,green_b, by.x = "ID", by.y = "id")

nir_b <- image_params[image_params$band=="proche IR",][,c(2:7)]
names(nir_b) = c("nir_min","nir_max","nir_mean","nir_std", "nir_median","id")
nir_b <- nir_b[!duplicated(nir_b$id),]
RESP_params<-merge(RESP_params,nir_b, by.x = "ID", by.y = "id")

ndvi_b <- image_params[image_params$band=="ndvi",][,c(2:7)]
names(ndvi_b) = c("ndvi_min","ndvi_max","ndvi_mean","ndvi_std", "ndvi_median","id")
ndvi_b <- ndvi_b[!duplicated(ndvi_b$id),]
RESP_params<-merge(RESP_params,ndvi_b, by.x = "ID", by.y = "id")

pca_ir <- read.csv(paste0(SIM_STATS,"PCA_beeches_proche IR_band_values.csv"))
pca_ir <- pca_ir[,-c(6)]
names(pca_ir) = c("PC1_nir","PC2_nir","PC3_nir","PC4_nir", "PC5_nir","id")
pca_ir <- pca_ir[!duplicated(pca_ir$id),]
RESP_params<-merge(RESP_params,pca_ir, by.x = "ID", by.y = "id")

pca_blue <- read.csv(paste0(SIM_STATS,"PCA_beeches_bleu_band_values.csv")) # pc1
pca_blue <- pca_blue[,-c(6)]
names(pca_blue) = c("PC1_b","PC2_b","PC3_b","PC4_b", "PC5_b","id")
pca_blue <- pca_blue[!duplicated(pca_blue$id),]
RESP_params<-merge(RESP_params,pca_blue, by.x = "ID", by.y = "id")

pca_ndvi <- read.csv(paste0(SIM_STATS,"PCA_beeches_ndvi_band_values.csv")) # pc1 and pc2
pca_ndvi <- pca_ndvi[,-c(6)]
names(pca_ndvi) = c("PC1_ndvi","PC2_ndvi","PC3_ndvi","PC4_ndvi", "PC5_ndvi","id")
pca_ndvi <- pca_ndvi[!duplicated(pca_ndvi$id),]
RESP_params<-merge(RESP_params,pca_ndvi, by.x = "ID", by.y = "id")

pca_red <- read.csv(paste0(SIM_STATS,"PCA_beeches_rouge_band_values.csv")) # pas intéressant
pca_red <- pca_red[,-c(6)]
names(pca_red) = c("PC1_red","PC2_red","PC3_red","PC4_red", "PC5_red","id")
pca_red <- pca_red[!duplicated(pca_red$id),]
RESP_params<-merge(RESP_params,pca_red, by.x = "ID", by.y = "id")

pca_vert <- read.csv(paste0(SIM_STATS,"PCA_beeches_vert_band_values.csv")) # pas intéressant
pca_vert <- pca_vert[,-c(6)]
names(pca_vert) = c("PC1_vert","PC2_green","PC3_green","PC4_green", "PC5_green","id")
pca_vert <- pca_vert[!duplicated(pca_vert$id),]
RESP_params<-merge(RESP_params,pca_vert, by.x = "ID", by.y = "id")



## Write outputs ##
write.csv(RESP_params, paste0(OUT_DIR,CSV_NAME),row.names=FALSE)

