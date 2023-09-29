import os, sys
import yaml
import time
import warnings
from tqdm import tqdm
from loguru import logger
from shapely.ops import unary_union

import geopandas as gpd
import pandas as pd
from rasterstats import zonal_stats

sys.path.insert(1, 'scripts')
import functions.fct_misc as fct_misc
from functions.fct_stats import pca_procedure

logger=fct_misc.format_logger(logger)
# warnings.filterwarnings("ignore",
#                         message=".*The definition of projected CRS EPSG:2056 got from GeoTIFF keys is not the same as the one from the EPSG registry.*")

tic = time.time()
logger.info('Starting...')

logger.info(f"Using config.yaml as config file.")
with open('config/config_ImPro.yaml') as fp:
        cfg = yaml.load(fp, Loader=yaml.FullLoader)['stats_per_tree.py']

logger.info('Defining constants...')

USE_FILTER=cfg['use_height_filter']
WORKING_DIR=cfg['working_directory']
INPUTS=cfg['inputs']

ORTHO_DIR=INPUTS['ortho_directory']
NDVI_DIR =INPUTS['ndvi_directory']
OUTPUT_DIR=cfg['output_directory']

CHM=INPUTS['chm']

TILE_DELIMITATION=INPUTS['tile_delimitation']

BEECHES_POLYGONS=INPUTS['beech_file']
BEECHES_LAYER=INPUTS['beech_layer']

os.chdir(WORKING_DIR)
written_files=[]

table_path=fct_misc.ensure_dir_exists(os.path.join(OUTPUT_DIR,'tables/seg'))
im_path=fct_misc.ensure_dir_exists(os.path.join(OUTPUT_DIR,'images/seg'))

logger.info('Reading files...')

beeches=gpd.read_file(BEECHES_POLYGONS) #CONTINUOUS
beeches.drop(columns=['zq99_seg', 'alpha_seg', 'beta_seg', 'cvlad_seg', 'vci_seg', 'i_mean_seg','i_sd_seg'], inplace=True) #CONTINUOUS

chm=fct_misc.polygonize_binary_raster(CHM)

tiles=gpd.read_file(TILE_DELIMITATION)

logger.info('Retriving and formatting all the necessary information...')

if USE_FILTER:     
    fct_misc.test_crs(beeches.crs, chm.crs)
    correct_high_beeches=gpd.overlay(beeches, chm)
    correct_high_beeches.drop(columns=['class'], inplace=True)
else:
    correct_high_beeches=beeches.copy()

if 'downsampled' not in ORTHO_DIR:
    tiles=fct_misc.get_ortho_tiles(tiles, ORTHO_DIR, NDVI_DIR)
else:
    tiles['path_RGB']=[os.path.join(ORTHO_DIR, tile_name + '.tif') for tile_name in tiles.NAME.to_numpy()]
    tiles['path_NDVI']=[os.path.join(NDVI_DIR, tile_name + '_NDVI.tif') for tile_name in tiles.NAME.to_numpy()]

clipped_beeches=fct_misc.clip_labels(correct_high_beeches, tiles)

# CONTINUOUS
# for health_class in clipped_beeches['etat_sanitaire'].unique():
#     logger.info(f"There are {clipped_beeches[clipped_beeches['etat_sanitaire']==health_class].shape[0]} beeches "+
#                 f"with the health status '{health_class}'")

clipped_beeches=clipped_beeches[~clipped_beeches.is_empty]

logger.info('Getting the statistics of trees...')
beeches_stats=pd.DataFrame()
BANDS={1: 'rouge', 2: 'vert', 3: 'bleu', 4: 'proche IR'}
calculated_stats=['min', 'max', 'mean', 'median', 'std']

single_beeches = pd.DataFrame()
for no in tqdm(clipped_beeches.segID.unique(),
                  desc='Merging double segID', total=clipped_beeches.shape[0]):
    mergedPolys = unary_union(clipped_beeches[clipped_beeches.segID==no].geometry)
    tmp = clipped_beeches[clipped_beeches.segID==no].iloc[:1]
    tmp.geometry.geometry.iloc[0] = mergedPolys
    single_beeches = pd.concat([single_beeches, pd.DataFrame(tmp)], ignore_index=True)

clipped_beeches  = gpd.GeoDataFrame(single_beeches, crs="EPSG:2056", geometry=single_beeches.geometry)
del single_beeches

for beech in tqdm(clipped_beeches.itertuples(),
                  desc='Extracting statistics over beeches', total=clipped_beeches.shape[0]):
    for band_num in BANDS.keys():
        stats_rgb=zonal_stats(beech.geometry, beech.path_RGB, stats=calculated_stats,
            band=band_num, nodata=9999)

        stats_dict_rgb=stats_rgb[0]
        #stats_dict_rgb['no_arbre']=beech.no_arbre
        stats_dict_rgb['segID']=beech.segID #CONTINUOUS
        stats_dict_rgb['band']=BANDS[band_num]
        # stats_dict_rgb['health_status']=beech.etat_sanitaire #CONTINUOUS

        beeches_stats=pd.concat([beeches_stats, pd.DataFrame(stats_dict_rgb, index=[0])], ignore_index=True)
    
    stats_ndvi=zonal_stats(beech.geometry, beech.path_NDVI, stats=calculated_stats,
        band=1, nodata=99999)
    
    stats_dict_ndvi=stats_ndvi[0]
    #stats_dict_rgb['no_arbre']=beech.no_arbre
    stats_dict_ndvi['segID']=beech.segID #CONTINUOUS
    stats_dict_ndvi['band']='ndvi'
    # stats_dict_ndvi['health_status']=beech.etat_sanitaire #CONTINUOUS

    beeches_stats=pd.concat([beeches_stats, pd.DataFrame(stats_dict_ndvi, index=[0])], ignore_index=True)

rounded_stats=beeches_stats.copy()
cols=['min', 'max', 'median', 'mean', 'std']
rounded_stats[cols]=rounded_stats[cols].round(3)

filepath=os.path.join(table_path, 'beech_stats.csv')
rounded_stats.to_csv(filepath)
written_files.append(filepath)
del rounded_stats, cols, filepath

# CONTINOUS
# beeches_stats.loc[beeches_stats['health_status']=='sain', 'health_status']='1. sain'
# beeches_stats.loc[beeches_stats['health_status']=='malade', 'health_status']='2. malade'
# beeches_stats.loc[beeches_stats['health_status']=='mort', 'health_status']='3. mort'
# beeches_stats.rename(columns={'no_arbre': 'id'}, inplace=True)
beeches_stats.rename(columns={'segID': 'id'}, inplace=True)

# logger.info('Making some boxplots')
# for band in beeches_stats['band'].unique():

#     band_stats=beeches_stats[beeches_stats['band']==band]

#     bxplt_beeches=band_stats[calculated_stats + ['health_status']].plot.box(
#                                 by='health_status',
#                                 title=f'Distribution des statistiques sur les hêtres pour la bande {band}',
#                                 figsize=(18, 5),
#                                 grid=True,
#     )

#     fig=bxplt_beeches[0].get_figure()
#     filepath=os.path.join(im_path, f'boxplot_stats_band_{band}.jpg')
#     fig.savefig(filepath, bbox_inches='tight')
#     written_files.append(filepath)

### CM : in case of NAN issue in PCA 
beeches_stats = beeches_stats.dropna(axis=0,how='any')

logger.info('Making some PCAs')
for band in beeches_stats['band'].unique():
    features = calculated_stats
    ## CONTINOUS to_describe='health_status'
    to_describe='band'
    band_stats=beeches_stats[beeches_stats['band']==band]

    written_files_pca_pixels=pca_procedure(band_stats, features, to_describe,
                            table_path, im_path, 
                            file_prefix=f'PCA_beeches_{band}_band',
                            title_graph=f'PCA des hêtres en fonction de leur état de santé sur la bande {band}')

    written_files.extend(written_files_pca_pixels)

logger.success('Some files were written:')
for file in written_files:
    print(file)