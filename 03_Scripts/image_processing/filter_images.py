import os, sys
import yaml
import time
from loguru import logger
from tqdm import tqdm

import geopandas as gpd
import pandas as pd
import rasterio

import cv2
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

_ = fct_misc.ensure_dir_exists(DESTINATION_DIR)
os.chdir(WORKING_DIR)

logger.info('Reading file...')
tiles=gpd.read_file(TILE_DELIMITATION)

tiles=fct_misc.get_ortho_tiles(tiles)


bands=range(1,5)
for tile in tqdm(tiles.itertuples(), desc='Filtering tiles', total=tiles.shape[0]):
    with rasterio.open(tile.path_RGB) as src:
        im=src.read(bands)
        im_profile=src.profile

    filtered_image=im

    for band in bands:
        im_band=im[band-1, :, :]
        filtered_band=scipy.ndimage.gaussian_filter(im_band, sigma=10)
        filtered_image[band-1, :, :]=filtered_band

    tilepath=os.path.join(DESTINATION_DIR, tile.NAME + '_filtered.tif')
    im_profile.update(count= 4)
    with rasterio.open(tilepath, 'w', **im_profile) as dst:
            dst.write(filtered_image)
