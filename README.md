# Automatic estimation of the health state of beech trees in the canton of jura using airborne imagery and lidar point cloud

This project provides a suite of Python, R and Octave/Matlab scripts allowing the end-user to use Machine Learning to assess beech tree health grade based on orthophoto and LiDAR point cloud. 

## Hardware requirements

No specific requirements. 

## Software Requirements

* Python 3.8: Dependencies may be installed with either `pip` or `conda`, by making use of the provided `requirements.txt` file. The following method was tested successfully on a Windows system: 

    ```bash
    $ conda create -n <the name of the virtual env> -c conda-forge python=3.8
    $ conda activate <the name of the virtual env>
    $ pip install -r requirements.txt
    ```
* R: For installation of R, please follow the steps in https://cran.r-project.org/. Afterwards, install the necessary packages given in the script `/setup/environment.R`. To do that, run the mentionned script in RStudio.

* Octave/Matlab: For installation of Octave/Matlab, please follow the steps in https://octave.org/download.

## Folder structure

```
├── config                        # config files
├── data                          # dataset folder
   ├── 01_initial                 # initial data (as delivered)
      ├── AOI                     # AOI shape file
      ├── ground_truth            # ground truth shape file
      ├── lidar_point_cloud       # 
         └── original             # original classiefied lidar point cloud
      └── true_orthophoto         #
         └── original             #
            └── tiles             # tiles of the original true orthophoto
   ├── 02_intermediate            # intermediate results and processed data
      ├── AOI                     # 
         └── tiles                # splitted AOI tiles 
      ├── ground_truth            # cleaned ground truth shape files
      ├── lidar_point_cloud       #
         ├── downsampled          # downsampled lidar point cloud
            ├── dft_outputs       # DFT outputs for dowsampled LiDAR point cloud
            └── fhi_outputs       # Forest Health Index outputs for downsampled LiDAR point cloud
         └── original             # 
            ├── dft_outputs       # DFT outputs for original LiDAR point cloud
            └── fhi_outputs       # Forest Health Index outputs for original LiDAr point cloud
      ├── rf                      # random forest descriptors table
      ├── satellite_images        # 
         └── ndvi_diff            # yearly difference of NDVI from waldmonitoring.ch
      └── true_orthophoto
         └── downsampled
            ├── images            # boxplots and PCA histogramms for each bands
               ├── gt             # ... for ground truth
               └── seg            # ... for segmented trees
            ├── ndvi              # ndvi tiles computed from NRGB tiles
            ├── tables            # statstics and pca on NRGB-bands
               ├── gt             # ... for ground truth
               └── seg            # ... for segmented trees
              └── tiles           # downsampled tiles of the original true orthophoto
         └── original
            ├── images            # boxplots and PCA histogramms for each bands
               ├── gt             # ... for ground truth
               └── seg            # ... for segmented trees
            ├── ndvi              # ndvi tiles computed from NRGB tiles
            └── tables            # statstics and pca on NRGB-bands
               ├── gt             # ... for ground truth
               └── seg            # ... for segmented trees
   ├── 03_final                   # final data for product delivery
      └── rf                      # random forest prediction and trained model
├── documentation                 # documentation folder
├── scripts
   ├── DFT                        # Digital Forestry Toolbox as downloaded
   ├── image_processing           # set of functions for image processing
   ├── downloadNDVIdiff.py        # download the yearly difference of NDVI from the waldmonitoring.ch website
   ├── FHI_catalog.R              # descriptors computation from LiDAR point cloud
   ├── functions.R                # self-coded functions used in R scripts
   ├── funPeaks.m                 # script using functions from DFT to segment LiDAR point cloud
   ├── funPeaks_batch.m           # script to segment all the LAS files in a folder 
   ├── mergeData_inpoly.R         # prepare descriptors and response variables table for RF  
   ├── RF.R                       # random Forest routine (dataset split, training, otpimisation, prediction)
   └── subsampleLAS.py            # subsample LiDAR point cloud by a factor 5
└── setup                         # utility to setup the environment
```

## Scripts and Procedure

Scripts can be found in the `scripts` folder: 

1. `downloadNDVIdiff.py`
2. `subsampleLAS.py`
3. `image_processing/scripts/filter_images.py`
4. `funPeaks_batch.m`
5. `FHI_catalog.R`
6. `images_processing/scripts/calculate_ndvi.py`
7. `images_processing/scripts/stats_per_tree.py`
8. `mergeData_inpoly.R`
9. `RF.R`

and can be run following this very order after checking/editing parameters in different configuration files available in the `/config/` folder. 

The following terminology will be used throughout the rest of this document:

* **ground truth data**: data to be used to train the Macine Learning-based predictive model; such data is expected to be 100% true 

* **GT**: abbreviation of ground truth

* **other data**: data that is not ground-truth-grade 

* **RF**: abbreviation of random forest

* **descriptors**: other data processed so that they may describe beech tree health state. 

* **AOI**, abbreviation of "area of interest": geographical area over which the user intend to carry out the analysis. This area encompasses 
  * regions for which ground-truth data is available, as well as 
  * regions over which the user intends to detect potentially unknown objects

* **tiles**, or - more explicitly - "geographical map tiles" 

* **trn**, **val**, **tst**, **oth**: abbreviations of "training", "validation", "test" and "other", respectively

### Data preparation

#### Yearly NDVI differences download
Yearly NDVI differences is downloaded from waldmonitoring.ch. Run the script `/scritps/downloadNDVIdiff.py` in the Python environment. 

#### LiDAR point cloud subsampling
LiDAR point cloud are subsampled to have a similar density as the swisstopo product swissSURFACE3D. Subsample the LAS files running the script `/scripts/subsampleLAS.py` in the Python environment. 

#### Orthophoto downsampled
The true orthophoto tiles are downsampled to have a similar spatial resolution as the swisstopo product SWISSIMAGE RS. Downsample the orthoimages running the script `/script/image_processing/filter_images.py` in the Python environment. 

### Tree segmentation from LiDAR point cloud
LAS point cloud segmentation in individual trees is performed using the Digital Forestry Toolbox on Matlab/Octave:
* Go to Matthew Parkan's GitHub: https://mparkan.github.io/Digital-Forestry-Toolbox/
* Download the Digital Forestry Toolbox
* Unzip the files in the script folder `/scripts/`
* In `/mparkan-Digital-Forestry-Toolbox-v.1.0.2-75-gfaf6cdc/mparkan-Digital-Forestry-Toolbox-faf6cdc/` folder
	* Delete the `data` folder 
	* Move content of the folder in the folder `/scripts/DFT`
* Check the input paths in the Matlab/Octave script `funPeaks_batch.m`
	* When processing original data
	```
	DIR_IN = 'C:\...\proj-hetres\data\01_initial\lidar_point_cloud\original\'
	DIR_OUT = 'C:\...\proj-hetres\data\02_intermediate\lidar_point_cloud\original\dft_outputs\'
	```
	* When processing subsampled data
	```
	DIR_IN = 'C:\...\proj-hetres\data\02_intermediate\lidar_point_cloud\downsampled\'
	DIR_OUT = 'C:\...\proj-hetres\data\02_intermediate\lidar_point_cloud\downsampled\dft_outputs\' 
	```
* Run the Matlab/Octave script `funPeaks_batch.m` in Octave or Matlab


### Structural descriptors computation 
Structural descriptors are computed via RStudio, partly after the article from P. Meng et al (2022), DOI: 10.1080/17538947.2022.2059114:
* In RStudio, run the script /scripts/FHI/FHI_catalog.R with the correct parameter value in the the config file `/config/config_FHI.yml`
	* When processing original data
	```
	 DIR_LAS: "C:/.../proj-hetres/data/02_intermediate/lidar_point_cloud/original/dft_outputs/"
	 SIM_DIR: "C:/.../proj-hetres/data/02_intermediate/lidar_point_cloud/original/fhi_outputs/"
	```
	* When processing subsampled data
	```
	 DIR_LAS: "C:/.../proj-hetres/data/02_intermediate/lidar_point_cloud/downsampled/dft_outputs/"
	 SIM_DIR: "C:/.../proj-hetres/data/02_intermediate/lidar_point_cloud/downsampled/fhi_outputs/"
	```

### Image processing 
Image processing is performed on RGBNIR images to extract health information. Correct inputs and outpus directory and files have to be given in the `/confi/config_ImPro.yaml` file:
* First, compute the NDVI images using R and NIR band by running the script `calculate_ndvi.py`
	* When processing original data
	```
	ortho_directory: data/01_initial/true_orthophoto/original/tiles
	ndvi_directory: data/02_intermediate/true_orthophoto/original/ndvi
	```
	* When processing subsampled data
	```
	ortho_directory: data/02_intermediate/true_orthophoto/downsampled/tiles
	ndvi_directory: data/02_intermediate/true_orthophoto/downsampled/ndvi
	```
* Compute stats (min, max, mean, median, std) per band for the GT trees by running the script `stat_per_tree_gt.py`. 
	* Don’t use the height filter, since the polygons are adjusted on the crown. 
	* Specify parameters in  the `/confi/config_ImPro.yaml` config file: 
	```
	use_height_filter: false
	ortho_directory: data/01_initial/true_orthophoto/original/tiles/
	ndvi_directory: data/02_intermediate/true_orthophoto/original/ndvi/
	output_directory: data/02_intermediate/true_orthophoto/original/
	beech_file: data/02_intermediate/ground_truth/STDL_releves_poly_ok.gpkg
	```	
* Compute stats (min, max, mean, median, std) per band for the segmented trees by running the script `stat_per_tree_seg.py` 
	* Use the height filter to mask understory pixels. 
	* Specify parameters in  the `/confi/config_ImPro.yaml` config file: 
	```
	use_height_filter: true
	ortho_directory: data/02_intermediate/true_orthophoto/downsampled/tiles/
	ndvi_directory: data/02_intermediate/true_orthophoto/downsampled/ndvi/
	output_directory: data/02_intermediate/true_orthophoto/downsampled/
	beech_file: data/02_intermediate/lidar_point_cloud/original/fhi_outputs/mosaic_seg_params.shp
	```	

### Random Forest
Preparation of descriptors, training, optimization and prediction.
* Preparation of descriptor suscessively for the GT trees and the segmented treesMerge. Edit `/config/config_merge.yml` accordingly. 
	* For GT trees:
	```
	TRAIN_DATA : TRUE
	SIM_STATS_DIR: "C:/Users/cmarmy/Documents/STDL/Beeches/delivery/data/01_initial/true_orthophoto/original/tables/gt/"
	```
	* For segmented trees:
	```
	TRAIN_DATA : FALSE
	SIM_STATS_DIR: "C:/Users/cmarmy/Documents/STDL/Beeches/delivery/data/01_initial/true_orthophoto/original/tables/seg/"
	```
	* Change "original" for "downsampled" everywhere in `/config/config_merge.yml`, to compute corresponding outputs for downgraded data. 
* The script `RF.R` trains, optimizes and outputs GPKG with prediction for the segmented polygons. 
* The ground truth analysis was performed using …  



## Addendum

### Data preparation 

#### Ground truth 

The ground truth consists of beech trees with location and health state. 
* Collection of ground truth by the foresters (September 2022)
* Addition of extra trees after control of the RF predictions on field (July 2023)
* Delivery of a point vector file (coordinates + attributes) from the foresters
* Correction of coordinates with the help of the LiDAR point cloud (viewed in potree) and of the pictures taken on field.
* Removal of other species than beech trees
* Removal of candles (very late stage of dead trees, only trunk left)
* Removal of a few trees that are un-sharp on the true orthophoto
* Delineation of some tree crowns by hand, estimation of other tree crowns with a buffer in function of height around coordinates. 
* Conversion of 5 health classes (healthy, a bit unhealthy, middle unhealthy, very unhealthy, dead) to 3 classes (healthy, unhealthy, dead)

