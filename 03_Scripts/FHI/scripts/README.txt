FOLDER STRUCTURE
- wkdir
-- las
-- extent
-- scripts
-- results


SCRIPTS
0. functions.R - functions for FHI_sample.R, FHI_catalog.R, RF.R.
1. FHI_sample.R - processing of metrics for 1 segmented LAS tile.
2. FHI_catalog.R - processing of metrics for all (segmented) LAS tiles via the lidR catalog engine (for one sample see FHI_sample). 
3. mergeData.R - bring all data sources together on the GT coordinate. 
4. RF.R - Random Forest with mergeData.R CSV output. 
5. OF.R - Ordinal Forest test. 

FHI_analyse_param - ignore - Part for hierarchical structuring and health class attribution, no more actual 
help_lidR - ignore (just some useful line of codes)
backup1 - ignore
backup2 - ignore


DATA
- LAS data https://api.pub1.infomaniak.cloud/horizon/project/containers/container/proj-hetres/02_data/022_Processed/LiDAR/01_LiDAR/02_segmentation
- LAS extent https://api.pub1.infomaniak.cloud/horizon/project/containers/container/proj-hetres/02_data/022_Processed/LiDAR/01_LiDAR/02_segmentation/AOI
- Statistic from aerial imagery https://api.pub1.infomaniak.cloud/horizon/project/containers/container/proj-hetres/02_data/023_final/traitement_image/02_generalized/descriptors
- Indices from satellite imagery https://api.pub1.infomaniak.cloud/horizon/project/containers/container/proj-hetres/02_data/023_final/ground_truth https://api.pub1.infomaniak.cloud/horizon/project/containers/container/proj-hetres/02_data/023_final/traitement_image/02_generalized/descriptors
- Ground truth https://api.pub1.infomaniak.cloud/horizon/project/containers/container/proj-hetres/02_data/023_final/ground_truth

