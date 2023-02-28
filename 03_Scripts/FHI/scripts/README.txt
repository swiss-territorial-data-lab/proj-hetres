FOLDER STRUCTURE
- wkdir
-- data
-- extent
-- scripts
-- results


SCRIPTS
1. FHI_sample - processing of metrics per cell on one tile
2. FHI_catalog - processing of metrics for all tiles via the lidR catalog engine (for one sample see FHI_sample). 
3. FHI_analyse_param - Part for hierarchical structuring and health class attribution
4. RF - Random Forest reading the raster with parameter values and the GT SHP. 

backup1 - ignore
backup2 - ignore
help_lidR - ignore (just some useful line of codes)


DATA
- tiles extent https://api.pub1.infomaniak.cloud/horizon/project/containers/container/proj-hetres/02_dat[…]cquisition_image_LiDAR/02_CAD/01_TILING_SCHEMES/per_tile. Pour les points cloud correspondants 
- LAS data (to unzip) https://api.pub1.infomaniak.cloud/horizon/project/containers/container/proj-hetres/02_data/021_initial/acquisition_image_LiDAR/03_LIDAR/02_PROCESSED


