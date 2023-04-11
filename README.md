# proj-hetres

## Image processing

### Structure
The scripts all define a working folder. They will create the `processed` and `final` folders for their outputs. We recommend using the following directory structure:

```
.                   # Working folder
├── initial         # initial data from outside sources
|   └── True_ortho
|       └── Tiles
|           └── tiles for north AND south
├── processed       # transitory data produced by the scripts
└── final           # final data for the documentation and the beneficiaries
```

### Getting started
The following method and scripts were tested on a linux system.

#### Preprocessing
Once a python environment is created, ensure you have GDAL for Python installed (see commands below). Then, the necessary libraries can be installed with pip using the file `requirements.txt`. <br>
The base images can be processed to produce images with the NDVI value. Those are used if we choose to filter the images based on thresholds and to calculate the statistics per tree.

```
sudo apt-get install -y python3-gdal gdal-bin libgdal-dev gcc g++ python3.8-dev
pip install -r requirements.txt
python3 03_Scripts/image_processing/calculate_ndvi.py
```

#### Statistical tests
The script `stats_beeches_pixels.py` allows to make the boxplots and PCA based on the pixel values depending on the health class. It receives parameters from the config file:

```
stats_beeches_pixels.py:
    original_ortho:            # Boolean, whether the name of the images is formatted like the original images (true) or like filtered ones (false)                                      
    working_directory:          # Path to the working directory
    destination_directory:      # Path for the outputs images and tables
    inputs:
        ortho_directory:        # Folder of the ortho images
        tile_delimitation:      # Shapefile delimitating the tiles and with the attribute "NAME"
        north_chm:              # Binary CHM for the north zone (geotiff)
        south_chm:              # Binary CHM for the south zone (geotiff)
        beech_file:             # Geopackage with the polygons for the beeches
        beech_layer:            # Layer in the geopackage for the beeches
```

The script `stats_per_tree.py` allows to calculate the min, max, mean, median and standard deviation of the pixels over the beech polygons. Then, it produces the boxplots and PCA of those values over each band. It receives parameters from the config file. Those are the same than for the script `stats_beeches_pixels.py` except that the filtering based on the CHM can be disabled (`use_high_filter`) and that it can only use the original images.

The script `filter_images.py` allows to filter the original images. It receives the following parameters from the config file:

```
filter_images.py:
    filter_type:                  # Valid values: "gaussian", "downsampling", "sieve" and "thresholds"
    working_directory:            # Path to the working directory
    ortho_directory:              # Path to the ortho tiles when not using the original ones
    destination_directory:        # Path for the outputs images and tables
    tile_delimitation:            # Shapefile delimitating the tiles and with the attribute "NAME"
```