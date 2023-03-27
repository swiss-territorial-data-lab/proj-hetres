import os, sys
import yaml
import time
from loguru import logger
from tqdm import tqdm

import numpy as np
import geopandas as gpd
import rasterio
import gdal
from rasterio.enums import Resampling

import scipy

sys.path.insert(1, '03_Scripts')
import functions.fct_misc as fct_misc

logger=fct_misc.format_logger(logger)
tic = time.time()
logger.info('Starting...')

logger.info(f"Using config.yaml as config file.")
with open('03_Scripts/image_processing/config.yaml') as fp:
        cfg = yaml.load(fp, Loader=yaml.FullLoader)['filter_images.py']

logger.info('Defining constants...')

FILTER_TYPE=cfg['filter_type']

WORKING_DIR=cfg['working_directory']
DESTINATION_DIR=cfg['destination_directory']

TILE_DELIMITATION=cfg['tile_delimitation']

os.chdir(WORKING_DIR)
_ = fct_misc.ensure_dir_exists(DESTINATION_DIR)

logger.info('Reading file...')
tiles=gpd.read_file(TILE_DELIMITATION)

tiles=fct_misc.get_ortho_tiles(tiles)

bands=range(1,5)
thresholds={1: None, 2: None, 3: None, 4: 130, 5: 0.05}
for tile in tqdm(tiles.itertuples(), desc='Filtering tiles', total=tiles.shape[0]):
        
    if FILTER_TYPE in ['gaussian', 'thresholds', 'sieve']:
        with rasterio.open(tile.path_RGB) as src:
            im=src.read(bands)
            im_profile=src.profile


    if FILTER_TYPE=='gaussian':
        filtered_image=im.copy()
    
        for band in bands:
            im_band=im[band-1, :, :]
            filtered_band=scipy.ndimage.gaussian_filter(im_band, sigma=5)
            filtered_image[band-1, :, :]=filtered_band

        im_profile.update(count = 4)


    elif FILTER_TYPE=='thresholds':
        # Threshold based on the images of the script `stats_beeches_pixels.py`
        condition_image=im.copy()
        filtered_image=im[:3,:,:].copy()
        nbr_bands=0

        for band in bands:
            if thresholds[band]:
                im_band=im[band-1, :, :]
                condition_band= np.where(im_band>thresholds[band], 255, 0)

                nbr_bands+=1
                condition_image[nbr_bands-1, :, :]=condition_band

        if thresholds[5]:
            with rasterio.open(tile.path_NDVI) as src:
                im_ndvi=src.read(1)

            condition_band=np.where(im_ndvi>thresholds[5], 255, 0)
            nbr_bands+=1
            condition_image[nbr_bands-1, :, :]=condition_band

        # Hard-coded for the use of 3 cases based on 2 conditional images.
        filtered_image[0,:,:]=np.where((condition_image[0,:,:]==0) & (condition_image[1,:,:]==0), 255, 0)
        filtered_image[1,:,:]=np.where((condition_image[0,:,:]==255) & (condition_image[1,:,:]==255), 255, 0)
        filtered_image[2,:,:]=np.where(condition_image[0,:,:]!=condition_image[1,:,:], 255, 0)

        # filtered_image=filtered_image[:3,:,:]
        im_profile.update(count = 3)


    elif FILTER_TYPE=='sieve':
        # This filter actually puts a condition before applying the sieve filter in the goal of extacting the branches with
        # exclusively the use of the RGB branches.

        condition_band=np.where(im[0,:,:]<150, 0,
                                np.where(im[1,:,:]<150, 0,
                                         np.where(im[2,:,:]<150, 0, 1)))
        
        tilepath=os.path.join(DESTINATION_DIR, 'temp_'+tile.NAME+'_condition.tif')
        im_profile.update(count= 1)
        with rasterio.open(tilepath, 'w', **im_profile) as dst:
                dst.write(condition_band[np.newaxis, ...])
        
        conditional_im = gdal.Open(tilepath, 1)  # open image in read-write mode
        band = conditional_im.GetRasterBand(1)
        gdal.SieveFilter(srcBand=band, maskBand=None, dstBand=band, threshold=50, connectedness=8)

        arr = band.ReadAsArray()
        [rows, cols] = arr.shape
        driver = gdal.GetDriverByName("GTiff")
        outdata = driver.Create(os.path.join(DESTINATION_DIR, tile.NAME+'_filtered.tif'), cols, rows, 1, gdal.GDT_Byte)
        outdata.SetGeoTransform(conditional_im.GetGeoTransform())   ##sets same geotransform as input
        outdata.SetProjection(conditional_im.GetProjection())       ##sets same projection as input
        outdata.GetRasterBand(1).WriteArray(arr)

        os.remove(tilepath)
        continue

    elif FILTER_TYPE=='downsampling':
        scale=1/17
        
        with rasterio.open(tile.path_RGB) as dataset:
            # resample data to target shape
            filtered_image = dataset.read(
                out_shape=(
                    dataset.count,
                    int(dataset.height * scale),
                    int(dataset.width * scale)
                ),
                resampling=Resampling.bilinear
            )

            im_profile = dataset.profile.copy()
            # scale image transform
            transform = dataset.transform * dataset.transform.scale(
                (dataset.width / filtered_image.shape[-1]),
                (dataset.height / filtered_image.shape[-2])
            )
        
        im_profile.update({"height": filtered_image.shape[-2],
            "width": filtered_image.shape[-1],
            "transform": transform})

    else:
        logger.error('This type of filter is not implemented.'+
                    ' Only "gaussian", "downsampling", "sieve" and "threshold" are supported.')
        sys.exit(1)

    tilepath=os.path.join(DESTINATION_DIR, tile.NAME + '_filtered.tif')
    with rasterio.open(tilepath, 'w', **im_profile) as dst:
            dst.write(filtered_image)

logger.success(f'Done! The files were written in {DESTINATION_DIR}.')