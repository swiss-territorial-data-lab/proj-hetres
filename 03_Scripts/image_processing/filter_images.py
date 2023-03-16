import os, sys
import yaml
import time
from loguru import logger
from tqdm import tqdm

import numpy as np
import geopandas as gpd
import rasterio

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
    with rasterio.open(tile.path_RGB) as src:
        im=src.read(bands)
        im_profile=src.profile

    filtered_image=im.copy()
    
    for band in bands:
        im_band=im[band-1, :, :]
        if FILTER_TYPE=='gaussian':
            filtered_band=scipy.ndimage.gaussian_filter(im_band, sigma=5)
        elif FILTER_TYPE=='downsampling':
            filtered_band='xx'
        elif FILTER_TYPE=='thresholds':
            break
        else:
             logger.error('This type of filter is not implemented.'+
                          ' Only "gaussian", "downsampling" and "threshold" are supported.')
             sys.exit(1)
        
        filtered_image[band-1, :, :]=filtered_band
    im_profile.update(count = 4)

    if FILTER_TYPE=='thresholds':
        condition_image=im.copy()
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

        filtered_image[0,:,:]=np.where((condition_image[0,:,:]==0) & (condition_image[1,:,:]==0), 255, 0)
        filtered_image[1,:,:]=np.where((condition_image[0,:,:]==255) & (condition_image[1,:,:]==255), 255, 0)
        filtered_image[2,:,:]=np.where(condition_image[0,:,:]!=condition_image[1,:,:], 255, 0)

        filtered_image=filtered_image[:3,:,:]
        im_profile.update(count = 3)

    tilepath=os.path.join(DESTINATION_DIR, tile.NAME + '_filtered.tif')
    with rasterio.open(tilepath, 'w', **im_profile) as dst:
            dst.write(filtered_image)

logger.success(f'Done! The file were written in {DESTINATION_DIR}.')