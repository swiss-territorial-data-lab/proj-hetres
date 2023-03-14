import os, sys
import yaml
import logging, logging.config
import time


import geopandas as gpd
import pandas as pd
import numpy as np
import matplotlib
import rasterio

from glob import glob

sys.path.insert(1, '03_Scripts')
import functions.fct_misc as fct_misc
from functions.fct_stats import pca_procedure


logging.config.fileConfig('logging.conf')
logger = logging.getLogger('root')

tic = time.time()
logger.info('Starting...')

logger.info(f"Using config.yaml as config file.")
with open('03_Scripts/image_processing/config.yaml') as fp:
        cfg = yaml.load(fp, Loader=yaml.FullLoader)['stats_beeches_pixels.py']

logger.info('Defining constants...')


WORKING_DIR=cfg['working_directory']
INPUTS=cfg['inputs']

NORTH_ORTHO=INPUTS['north_ortho']
SOUTH_ORTHO=INPUTS['south_ortho']
NORTH_CHM=INPUTS['north_chm']
SOUTH_CHM=INPUTS['south_chm']

TILE_DELIMITATION=INPUTS['tile_delimitation']

BEECHES_POLYGONS=INPUTS['beech_file']
BEECHES_LAYER=INPUTS['beech_layer']

os.chdir(WORKING_DIR)
written_files=[]

table_path=fct_misc.ensure_dir_exists('final/tables')
im_path=fct_misc.ensure_dir_exists('final/images')

logger.info('Reading files...')

beeches=gpd.read_file(BEECHES_POLYGONS, layer=BEECHES_LAYER)

tiles_list_north=glob(NORTH_ORTHO)
tiles_list_south=glob(SOUTH_ORTHO)

north_chm=fct_misc.polygonize_binary_raster(NORTH_CHM)
south_chm=fct_misc.polygonize_binary_raster(SOUTH_CHM)
chm=pd.concat([north_chm, south_chm])
del north_chm, south_chm

tiles=gpd.read_file(TILE_DELIMITATION)

logger.info('Formatting pixel values and tiles...')

fct_misc.test_crs(beeches.crs, chm.crs)
correct_high_beeches=gpd.overlay(beeches, chm)
correct_high_beeches.drop(columns=['class'], inplace=True)

tiles_south=tiles[tiles['NAME'].str.startswith('258')]
beeches_south=correct_high_beeches[correct_high_beeches['zone']=='Miecourt']
beeches_on_tiles_south=gpd.overlay(beeches_south[['no_arbre', 'etat_sanitaire', 'geometry']],
                                    tiles_south[['NAME', 'geometry']])
beeches_on_tiles_south['filepath']=[os.path.join(SOUTH_ORTHO, 'South_ortho_JUHE_LV95_NF02_3cm_' + name + '.tif')
                                        for name in beeches_on_tiles_south['NAME'].values]
del tiles_south, beeches_south

tiles_north=tiles[tiles['NAME'].str.startswith('257')]
beeches_north=correct_high_beeches[correct_high_beeches['zone'].str.startswith('Beurnevesi')]
beeches_on_tiles_north=gpd.overlay(beeches_north[['no_arbre', 'etat_sanitaire', 'geometry']],
                                    tiles_north[['NAME', 'geometry']])
beeches_on_tiles_north['filepath']=[os.path.join(NORTH_ORTHO, 'North_ortho_JUHE_LV95_NF02_3cm_' + name + '.tif')
                                        for name in beeches_on_tiles_north['NAME'].values]
del tiles_north, beeches_north

pixels_south=pd.DataFrame()
for beech in beeches_on_tiles_south.itertuples():
    pixels=fct_misc.get_pixel_values(beech.geometry, beech.filepath, bands=range(1,5),
                                    health_status=beech.etat_sanitaire)

    pixels_south=pd.concat([pixels_south, pixels])

pixels_north=pd.DataFrame()
for beech in beeches_on_tiles_north.itertuples():
    pixels=fct_misc.get_pixel_values(beech.geometry, beech.filepath, bands=range(1,5),
        health_status=beech.etat_sanitaire)

    pixels_north=pd.concat([pixels_north, pixels])

pixels_beeches=pd.concat([pixels_north, pixels_south], ignore_index=True)
del pixels_north, pixels_south, pixels


logger.info('Calculating the NDVI for pixels...')
pixels_beeches.rename(columns={'band1':'Rouge', 'band2':'Vert', 'band3':'Bleu', 'band4':'Proche IR'}, inplace=True)
pixels_beeches['NDVI']=(pixels_beeches['Proche IR'].astype('float64')-
                            pixels_beeches['Rouge'].astype('float64'))/(pixels_beeches['Proche IR'].astype('float64')+
                                                                            pixels_beeches['Rouge'].astype('float64'))

pixels_beeches.loc[pixels_beeches['health_status']=='sain', 'health_status']='1. sain'
pixels_beeches.loc[pixels_beeches['health_status']=='malade', 'health_status']='2. malade'
pixels_beeches.loc[pixels_beeches['health_status']=='mort', 'health_status']='3. mort'

pixels_beeches=pixels_beeches[pixels_beeches['NDVI']<0.90]

logger.info('Making boxplots...')
boxplots=pixels_beeches.plot.box(by='health_status',
                            title='Distribution des pixels en fonction de l\'état sanitaire',
                            figsize=(16,5),
                            grid=True)
fig = boxplots[0].get_figure()
filename=os.path.join(im_path, 'bxplt_distribution_status_health.jpg')
fig.savefig(filename, bbox_inches='tight')
written_files.append(filename)

logger.info('Making PCAs...')
features = pixels_beeches.columns.tolist()
features.remove('health_status')
to_describe='health_status'

written_files_pca_pixels=pca_procedure(pixels_beeches, features, to_describe,
                        table_path, im_path, 
                        file_prefix=f'PCA_beeches_',
                        title_graph='PCA for the values of the pixels on each band and the NDVI')

written_files.extend(written_files_pca_pixels)

logger.info('Some files were written:')
for file in written_files:
    print(file)