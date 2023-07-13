import os, sys
import yaml
import time

import geopandas as gpd
import numpy as np
import rasterio

from loguru import logger
from tqdm import tqdm
from glob import glob


def calculate_ndvi(tile, band_nbr_red=0, band_nbr_nir=3, path=None):
    '''
    Calculate the NDVI for each pixel of a tile and save the result in a new folder.

    - tile: path to the tile
    - band_nbr_red: number of the red band in the image
    - band_nbr_nir: number of the nir band in the image
    - path: filepath were to save the result. If None, no file is saved
    return: array with the ndvi value for each pixel.
    '''

    with rasterio.open(tile) as src:
        image = src.read()
        im_profile=src.profile

    red_band=image[band_nbr_red].astype('float32')
    nir_band=image[band_nbr_nir].astype('float32')
    ndvi_tile=np.divide((nir_band - red_band),(nir_band + red_band),
                        out=np.zeros_like(nir_band - red_band),
                        where=(nir_band + red_band)!=0)

    if path:
        im_profile.update(count= 1, dtype='float32')
        with rasterio.open(path, 'w', **im_profile) as dst:
            dst.write(ndvi_tile,1)

    return ndvi_tile


if __name__ == "__main__":

    logger.remove()
    logger.add(sys.stderr, format="{time:YYYY-MM-DD HH:mm:ss} - {level} - {message}", level="INFO")

    tic = time.time()
    logger.info('Starting...')

    logger.info(f"Using config.yaml as config file.")
    with open('config/config_ImPro.yaml') as fp:
            cfg = yaml.load(fp, Loader=yaml.FullLoader)['calculate_ndvi.py']

    logger.info('Defining constants...')

    WORKING_DIR=cfg['working_directory']

    INPUTS=cfg['inputs']
    ORTHO=INPUTS['ortho_directory']
    NDVI=INPUTS['ndvi_directory']

    TILE_DELIMITATION=INPUTS['tile_delimitation']

    os.chdir(WORKING_DIR)
    written_files=[]

    logger.info('Reading files...')
    
    tile_list_ortho=glob(os.path.join(ORTHO, '*.tif'))
    aoi_tiles=gpd.read_file(TILE_DELIMITATION)

    tile_list=[]
    tile_list.extend(tile_list_ortho)

    for tile in tqdm(tile_list, 'Processing tiles'):
        tile = tile.replace("\\","/") #handle windows path
        ndvi_tile_path=os.path.join(NDVI, tile.split('/')[-1].replace('.tif', '_NDVI.tif'))
        _ = calculate_ndvi(tile, path=ndvi_tile_path)
        written_files.append(ndvi_tile_path)

    logger.info('Some files were written:')
    for file in written_files:
        print(file)