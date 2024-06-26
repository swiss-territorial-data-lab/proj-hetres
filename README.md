# Automatic estimation of the health state for trees based on airborne imagery and LiDAR point cloud

This project provides a suite of Python, R and Octave/Matlab scripts allowing the end-user to use machine learning to assess the health state of trees based on orthophotos and a LiDAR point cloud. 

## Hardware requirements

No specific requirements. 

## Software Requirements

* Python 3.8: The dependencies may be installed with either `pip` or `conda`, by making use of the provided `requirements.txt` file. The following method was tested successfully on a Windows system: 

    ```bash
    $ conda create -n <the name of the virtual env> -c conda-forge python=3.10 gdal
    $ conda activate <the name of the virtual env>
    $ pip install -r setup/requirements.txt
    ```
* R: For the installation of R, please follow the steps in https://cran.r-project.org/. Afterwards, install the necessary packages given in the script `setup/environment.R`. To do that, run the mentioned script in RStudio.

* Octave/Matlab: For the installation of Octave/Matlab, please follow the steps in https://octave.org/download.

## Folder structure

```
├── config                        # config files
├── scripts                       #
   ├── data_preparation
      ├── downloadNDVIdiff.py     # download the yearly variation of NDVI from waldmonitoring.ch website	  
      ├── downsampleLAS.py        # downsample LiDAR point cloud by a factor 5   
      └── generateAOIvector.py    # generate extent for each tile and made a grid out of them.  
   ├── DFT                        # Digital Forestry Toolbox once downloaded
   ├── functions                  # set of functions used in R and python scripts
   ├── image_processing           # set of scripts for image processing
   ├── FHI_catalog.R              # descriptors computation from LiDAR point cloud
   ├── RF.R                       # random forest routine (dataset split, training, optimization, prediction)
   ├── funPeaks.m                 # use functions from DFT to segment the LiDAR point cloud
   ├── funPeaks_batch.m           # segment all the LAS files in a folder 
   └── mergeData_inpoly.R         # prepare descriptors and response variables table for RF  
└── setup                         # utility to setup the environment
```

## Scripts and Procedure

The following terminology will be used throughout this document:

* **descriptors**: data processed so that it may describe health state of beech trees. 

The following abbreviations are used:

* **AOI**: area of interest

* **GT**: ground truth

* **RF**: random forest

Scripts are run in combination with their hard-coded configuration files in the following order: 

1. `data_preparation/downloadNDVIdiff.py`
2. `data_preparation/downsampleLAS.py`
3. `data_preparation/generateAOIvector.py`
3. `images_processing/calculate_ndvi.py`
4. `image_processing/filter_images.py`
5. `funPeaks_batch.m`
6. `FHI_catalog.R`
7. `images_processing/stats_per_tree.py`
8. `mergeData_inpoly.R`
9. `RF.R`


### Data preparation

Run the following scripts in python: 

```
python scripts/data_preparation/downloadNDVIdiff.py
python scripts/data_preparation/downsampleLAS.py
python scripts/data_preparation/generateAOIvector.py
python scripts/image_processing/calculate_ndvi.py
```
1. Compute the NDVI images using the red and NIR bands,
	* Before processing the data, check the band order in TIF file and that correct values are indicated in line 17. 
	* When processing original data, indicate in the `config/config_ImPro.yaml` config file: 
	```
	ortho_directory: 01_initial/true_orthophoto/original/tiles
	ndvi_directory: 02_intermediate/true_orthophoto/original/ndvi
	```
	* When processing downsampled data, indicate in the `config/config_ImPro.yaml` config file: 
	```
	ortho_directory: 02_intermediate/true_orthophoto/downsampled/tiles
	ndvi_directory: 02_intermediate/true_orthophoto/downsampled/ndvi
	```
```
python scripts/image_processing/filter_images.py
```	
Those code lines perform the following tasks:

1. The yearly NDVI differences are downloaded from waldmonitoring.ch. 
2. The LiDAR point clouds are downsampled to have a similar density as the swisstopo product swissSURFACE3D.
3. AOI tile polygons based on input orthophoto tiles are generated.
4. The NDVI rasters corresponding to the aerial images are computed. 
5. The true orthophoto tiles are downsampled to have a similar spatial resolution as the swisstopo product SWISSIMAGE RS.

The second and five steps are facultative. The whole project can be run on the original or downsampled data.

### Tree segmentation from LiDAR point cloud
The segmentation of trees in the LAS point cloud is performed using the Digital Forestry Toolbox on Matlab/Octave:
* Go to Matthew Parkan's GitHub: https://mparkan.github.io/Digital-Forestry-Toolbox/
* Download the Digital Forestry Toolbox
* Unzip the files in the script folder `/scripts/`
* In `/mparkan-Digital-Forestry-Toolbox-v.1.0.2-75-gfaf6cdc/mparkan-Digital-Forestry-Toolbox-faf6cdc/` folder
	* Delete the `data` folder 
	* Move content of the folder in the folder `/scripts/DFT`
* Check the input paths in the Matlab/Octave script `funPeaks_batch.m`
	* When processing original data
	```
	WORKING_DIR='C:\Users\...\data\';
	DIR_IN =strcat(WORKING_DIR,  '01_initial\lidar_point_cloud\original\');
	DIR_OUT = strcat(WORKING_DIR, '02_intermediate\lidar_point_cloud\original\dft_outputs\');
	```
	* When processing downsampled data
	```
	WORKING_DIR='C:\Users\...\data\';
	DIR_IN =strcat(WORKING_DIR,  '01_initial\lidar_point_cloud\downsampled\');
	DIR_OUT = strcat(WORKING_DIR, '02_intermediate\lidar_point_cloud\downsampled\dft_outputs\');
	```
* Add the folder and subfolders of `scripts/DFT/scripts` to the Path (Edit -> Set Path)
* Run the Matlab/Octave script `funPeaks_batch.m` in Octave or Matlab

### Structural descriptors computation 
Structural descriptors are computed via RStudio, partly after the article from P. Meng et al (2022), DOI: 10.1080/17538947.2022.2059114:
* In RStudio, run the script `scripts/FHI_catalog.R` with the correct parameter values in the the config file `config/config_FHI.yml`
	* When processing original data
	```
	  WORKING_DIR: "C:/Users/.../data/"
	  DIR_LAS: "02_intermediate/lidar_point_cloud/original/dft_outputs/"
	  SIM_DIR: "02_intermediate/lidar_point_cloud/original/fhi_outputs/"
	```
	* When processing downsampled data
	```
	  WORKING_DIR: "C:/Users/.../data/"
	  DIR_LAS: "02_intermediate/lidar_point_cloud/downsampled/dft_outputs/"
	  SIM_DIR: "02_intermediate/lidar_point_cloud/downsampled/fhi_outputs/"
	```

### Image processing 
Image processing is performed on 4-bands images to extract health information. The correct input and output directories and files have to be given in the `config/config_ImPro.yaml` file.

```
python scripts/image_processing/stats_per_tree.py
```

1. Compute the statistics (min, max, mean, median, std) per band for the GT trees,
	* Don’t use the height filter, since the polygons are adjusted to the crown. 
	* Specify parameters in  the `config/config_ImPro.yaml` config file: 
	```
	GT: true
	use_height_filter: false
	beech_file: 02_intermediate/ground_truth/GT_3p0_poly_sub.gpkg
	```	
2. Compute the statistics (min, max, mean, median, std) per band for the segmented trees,
	* Use the height filter to mask understory pixels. 
	* Specify parameters in  the `config/config_ImPro.yaml` config file: 
	```
	GT: false
	use_height_filter: true
	beech_file: 02_intermediate/lidar_point_cloud/downsampled/fhi_outputs/mosaic_seg_params.shp
	```	

### Random Forest
To prepare the descriptors, train and optimize the model and make the predictions:

* Edit `config/config_merge.yml` for the preparation of the descriptors successively for the GT trees and the segmented trees:
	* For GT trees:
	```
	 WORKING_DIR: "C:/Users/.../data"
	 TRAIN_DATA : true
	 SIM_STATS_DIR: "02_intermediate/true_orthophoto/original/tables/gt/"
	```
	* For segmented trees:
	```
	 WORKING_DIR: "C:/Users/.../data"
	 TRAIN_DATA : false
	 SIM_STATS_DIR: "02_intermediate/true_orthophoto/original/tables/seg/"
	```
	* Change "original" for "downsampled" everywhere in `config/config_merge.yml`, to compute corresponding outputs for downgraded data. 
	* Use the script `RF.R` to train, optimize and output vector with predictions for the segmented polygons. One can choose which descriptors have to be included in the RF model with the DESCRIPTORS parameter. Furthermore, threshold to apply on the votes fraction can be tweaked with the CUTOFF parameter. 
	```
	 DESCRIPTORS: "all" # all, NDVI_diff, structural, stats, custom
	 CUTOFF: [0.33,0.33,0.33] # [0.2, 0.2, 0.2, 0.2, 0.2] # [0.35,0.29,0.33] 
	```

## Addendum

### Documentation
The full documentation of the project is available on the [STDL's technical website](https://tech.stdl.ch/PROJ-HETRES/).

### Data 

#### Ground truth 

The ground truth consists of beech trees with location and health state. 
* Collection of ground truth by the foresters (September 2022)
* Addition of extra trees after control of the RF predictions on field (July 2023)
* Delivery of a point vector file (coordinates + attributes) from the foresters
* Correction of coordinates with the help of the LiDAR point cloud (visualized with potree) and the pictures taken on field.
* Removal of species other than beech trees
* Removal of candles (very late stage of dead trees, where only the trunk is left)
* Removal of a few trees that are un-sharp on the true orthophoto
* Delineation of some tree crowns by hand, estimation of other tree crowns with a buffer in function of the canopy diameter around coordinates. 
* Conversion of 5 health classes (healthy, a bit unhealthy, middle unhealthy, very unhealthy, dead) to 3 classes (healthy, unhealthy, dead)

#### Structure

The scripts expect the data in the project folder following the structure presented below.

```
├── data                          # dataset folder
   ├── 01_initial                 # initial data (as delivered)
      ├── AOI                     # AOI shape file
      ├── ground_truth            # ground truth shape file
      ├── lidar_point_cloud       # 
         └── original             # original classified LiDAR point cloud
      └── true_orthophoto         #
         └── original             #
            └── tiles             # tiles of the original true orthophoto
   ├── 02_intermediate            # intermediate results and processed data
      ├── AOI                     # 
         └── tiles                # split AOI tiles 
      ├── ground_truth            # cleaned ground truth shape files
      ├── lidar_point_cloud       #
         ├── downsampled          # downsampled LiDAR point cloud
            ├── dft_outputs       # DFT outputs for downsampled LiDAR point cloud
            └── fhi_outputs       # Forest Health Index outputs for downsampled LiDAR point cloud
         └── original             # 
            ├── dft_outputs       # DFT outputs for original LiDAR point cloud
            └── fhi_outputs       # Forest Health Index outputs for original LiDAR point cloud
      ├── rf                      # random forest descriptors table
	        ├── downsampled       #
			└── original		  #
      ├── satellite_images        # 
         └── ndvi_diff            # yearly difference of NDVI from waldmonitoring.ch
      └── true_orthophoto
         └── downsampled
            ├── images            # boxplots and PCA for each bands
               ├── gt             # ... for ground truth
               └── seg            # ... for segmented trees
            ├── ndvi              # NDVI tiles computed from NirRGB tiles
            ├── tables            # statistics and pca on NirRGB-bands
               ├── gt             # ... for ground truth
               └── seg            # ... for segmented trees
              └── tiles           # downsampled tiles of the original true orthophoto
         └── original
            ├── images            # boxplots and PCA for each bands
               ├── gt             # ... for ground truth
               └── seg            # ... for segmented trees
            ├── ndvi              # NDVI tiles computed from NirRGB tiles
            └── tables            # statistics and pca on NirRGB-bands
               ├── gt             # ... for ground truth
               └── seg            # ... for segmented trees
```
