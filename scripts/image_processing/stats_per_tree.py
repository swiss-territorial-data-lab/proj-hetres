import os, sys
import yaml
import warnings
from tqdm import tqdm
from loguru import logger

import geopandas as gpd
import pandas as pd
from rasterstats import zonal_stats

from joblib import Parallel, delayed
import multiprocessing
from threading import Lock

sys.path.insert(1, 'scripts')
import functions.fct_misc as fct_misc
from functions.fct_stats import pca_procedure


def do_statistics(beech):
    beeches_stats_list=pd.DataFrame()
    for band_num in BANDS.keys():
        stats_rgb=zonal_stats(beech.geometry, beech.path_RGB, stats=calculated_stats,
        band=band_num, nodata=9999)

        stats_dict_rgb=stats_rgb[0]
        if GT:
            stats_dict_rgb['no_arbre']=beech.no_arbre
            stats_dict_rgb['band']=BANDS[band_num]
            stats_dict_rgb['health_status']=beech.etat_sanitaire
            stats_dict_rgb['area']= beech.geometry.area                                           
        else: 
            stats_dict_rgb['segID']=beech.segID
            stats_dict_rgb['band']=BANDS[band_num]
            stats_dict_rgb['area']= beech.geometry.area        
       
        beeches_stats_list=beeches_stats_list.append(pd.DataFrame(stats_dict_rgb, index=[0]))
    
    stats_ndvi=zonal_stats(beech.geometry, beech.path_NDVI, stats=calculated_stats,
        band=1, nodata=99999)
    
    stats_dict_ndvi=stats_ndvi[0]
    if GT:
        stats_dict_ndvi['no_arbre']=beech.no_arbre
        stats_dict_ndvi['band']='ndvi'
        stats_dict_ndvi['health_status']=beech.etat_sanitaire
        stats_dict_ndvi['area']= beech.geometry.area                                           
    else: 
        stats_dict_ndvi['segID']=beech.segID    
        stats_dict_ndvi['band']='ndvi'     
        stats_dict_ndvi['area']= beech.geometry.area     
                          
    beeches_stats_list=beeches_stats_list.append(pd.DataFrame(stats_dict_ndvi, index=[0]))
    
    return beeches_stats_list

def do_merge_gt(no):
    single_beeches_list=pd.DataFrame()
    for band_num in CHANNELS.keys():
        max_max = max(beeches_stats.loc[(beeches_stats['no_arbre']==no) & (beeches_stats['band']==CHANNELS[band_num])]['max'])
        min_min = min(beeches_stats.loc[(beeches_stats['no_arbre']==no) & (beeches_stats['band']==CHANNELS[band_num])]['min'])
        means = (beeches_stats.loc[(beeches_stats['no_arbre']==no) & (beeches_stats['band']==CHANNELS[band_num])]['mean']).values
        medians = (beeches_stats.loc[(beeches_stats['no_arbre']==no) & (beeches_stats['band']==CHANNELS[band_num])]['median']).values
        stds = (beeches_stats.loc[(beeches_stats['no_arbre']==no) & (beeches_stats['band']==CHANNELS[band_num])]['std']).values
        areas = (beeches_stats.loc[(beeches_stats['no_arbre']==no) & (beeches_stats['band']==CHANNELS[band_num])]['area']).values
        mean_wgtd = sum(means*areas)/sum(areas)
        median_wgtd = sum(medians*areas)/sum(areas)
        std_wgtd = sum(stds*areas)/sum(areas)

        tmp = beeches_stats[beeches_stats.no_arbre==no].iloc[band_num-1:band_num]
        tmp['min']=min_min
        tmp['max']=max_max
        tmp['mean']=mean_wgtd
        tmp['median']=median_wgtd
        tmp['std']=std_wgtd

        single_beeches_list = single_beeches_list.append(tmp)

    return single_beeches_list

lock = Lock()

logger=fct_misc.format_logger(logger)
# warnings.filterwarnings("ignore",
#                         message=".*The definition of projected CRS EPSG:2056 got from GeoTIFF keys is not the same as the one from the EPSG registry.*")
logger.info('Starting...')

logger.info(f"Using config.yaml as config file.")
with open('config/config_ImPro.yaml') as fp:
        cfg = yaml.load(fp, Loader=yaml.FullLoader)['stats_per_tree.py']

logger.info('Defining constants...')

USE_FILTER=cfg['use_height_filter']
WORKING_DIR=cfg['working_directory']
INPUTS=cfg['inputs']
GT=cfg['GT']

ORTHO_DIR=INPUTS['ortho_directory']
NDVI_DIR=INPUTS['ndvi_directory']
OUTPUT_DIR=cfg['output_directory']

CHM=INPUTS['chm']

TILE_DELIMITATION=INPUTS['tile_delimitation']

BEECHES_POLYGONS=INPUTS['beech_file']
if GT:
    BEECHES_LAYER=INPUTS['beech_layer']

os.chdir(WORKING_DIR)
written_files=[]

if GT:
    table_path=fct_misc.ensure_dir_exists(os.path.join(OUTPUT_DIR,'tables/gt'))
    im_path=fct_misc.ensure_dir_exists(os.path.join(OUTPUT_DIR,'images/gt'))
else:
    table_path=fct_misc.ensure_dir_exists(os.path.join(OUTPUT_DIR,'tables/nohf'))
    im_path=fct_misc.ensure_dir_exists(os.path.join(OUTPUT_DIR,'images/nohf'))
logger.info('Reading files...')

if GT:
    beeches=gpd.read_file(BEECHES_POLYGONS, layer=BEECHES_LAYER)
    beeches.drop(columns=['essence', 'diam_tronc', 'nb_tronc', 'hauteur', 'verticalit', 'diametre_c', 'mortalite_',
                    'transparen', 'masse_foli', 'etat_tronc', 'etat_sanit', 'environnem',
                    'microtopog', 'pente', 'remarque', 'date_leve', 'responsabl',
                    'date_creat', 'vegetation', 'CLASS_SAN3', 'CLASS_SAN5', 'R_COURONNE', 'ZONE'], inplace=True)
    beeches.rename(columns={'NO_ARBRE':'no_arbre'}, inplace=True)
else: 
    beeches=gpd.read_file(BEECHES_POLYGONS)
    beeches.drop(columns=['zq99_seg', 'alpha_seg', 'beta_seg', 'cvlad_seg', 'vci_seg', 'i_mean_seg','i_sd_seg'], inplace=True)

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

clipped_beeches=clipped_beeches[~clipped_beeches.is_empty]
clipped_beeches=clipped_beeches[(clipped_beeches.geom_type=='Polygon')|(clipped_beeches.geom_type=='Multipolygon')]


logger.info('Getting the statistics of trees...')
BANDS={1: 'rouge', 2: 'vert', 3: 'bleu', 4: 'proche IR'}
CHANNELS={1: 'rouge', 2: 'vert', 3: 'bleu', 4: 'proche IR',5:'ndvi'}                                                                    
calculated_stats=['min', 'max', 'mean', 'median', 'std']

print("Multithreading with joblib for statistics over beeches: ")
num_cores = multiprocessing.cpu_count()
print ("starting job on {} cores.".format(num_cores))

logger.info('Extracting statistics over beeches...')
beeches_stats_list = Parallel(n_jobs=num_cores, prefer="threads")(delayed(do_statistics)(beech) for beech in clipped_beeches.itertuples())

beeches_stats=pd.DataFrame()
for row in beeches_stats_list:
    beeches_stats = beeches_stats.append(row, ignore_index=True)
logger.info('... finished')

if GT:
    logger.info('Merging double no_arbre...')
    single_beeches_list = Parallel(n_jobs=num_cores, prefer="threads")(delayed(do_merge_gt)(no) for no in list(beeches_stats.no_arbre.unique()))

    single_beeches=pd.DataFrame()
    for row in single_beeches_list:
        single_beeches = single_beeches.append(row, ignore_index=True)
    logger.info('... finished.')

    single_beeches.drop(columns=['area'])
    beeches_stats = single_beeches
    del single_beeches

rounded_stats=beeches_stats.copy()
cols=['min', 'max', 'median', 'mean', 'std']
rounded_stats[cols]=rounded_stats[cols].round(3)

filepath=os.path.join(table_path, 'beech_stats.csv')
rounded_stats.to_csv(filepath)
written_files.append(filepath)
del rounded_stats, cols, filepath

if GT:
    beeches_stats.loc[beeches_stats['health_status']=='sain', 'health_status']='1. sain'
    beeches_stats.loc[beeches_stats['health_status']=='malade', 'health_status']='2. malade'
    beeches_stats.loc[beeches_stats['health_status']=='mort', 'health_status']='3. mort'
    beeches_stats.rename(columns={'no_arbre': 'id'}, inplace=True)
else: 
    beeches_stats.rename(columns={'segID': 'id'}, inplace=True)

beeches_stats = beeches_stats.dropna(axis=0,how='any')
for band in beeches_stats['band'].unique():
    if GT: 
        logger.info(f'For band {band}...')
        band_stats=beeches_stats[beeches_stats['band']==band]

        logger.info('... making some boxplots...')
        bxplt_beeches=band_stats[calculated_stats + ['health_status']].plot.box(
                                    by='health_status',
                                    title=f'Distribution des statistiques sur les hêtres pour la bande {band}',
                                    figsize=(18, 5),
                                    grid=True,
        )

        fig=bxplt_beeches[0].get_figure()
        filepath=os.path.join(im_path, f'boxplot_stats_band_{band}.jpg')
        fig.savefig(filepath, bbox_inches='tight')
        written_files.append(filepath)

    logger.info('... calculating the PCA...')
    features = calculated_stats
    if GT:
        to_describe='health_status'
    else: 
        to_describe='band'
    band_stats=beeches_stats[beeches_stats['band']==band]

    written_files_pca_pixels=pca_procedure(band_stats, features, to_describe,
                            table_path, im_path, 
                            file_prefix=f'PCA_beeches_{band}_band',
                            title_graph=f'PCA des hêtres en fonction de leur état de santé sur la bande {band}')

    written_files.extend(written_files_pca_pixels)

