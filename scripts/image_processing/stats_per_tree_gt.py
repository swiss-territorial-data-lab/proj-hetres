import os, sys
import yaml
import warnings
from tqdm import tqdm
from loguru import logger

import geopandas as gpd
import pandas as pd
from rasterstats import zonal_stats
from shapely.ops import unary_union

sys.path.insert(1, 'scripts')
import functions.fct_misc as fct_misc
from functions.fct_stats import pca_procedure, lda_procedure

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

ORTHO_DIR=INPUTS['ortho_directory']
NDVI_DIR=INPUTS['ndvi_directory']
OUTPUT_DIR=INPUTS['output_directory']

CHM=INPUTS['chm']

TILE_DELIMITATION=INPUTS['tile_delimitation']

BEECHES_POLYGONS=INPUTS['beech_file']
BEECHES_LAYER=INPUTS['beech_layer']

os.chdir(WORKING_DIR)
written_files=[]

table_path=fct_misc.ensure_dir_exists(os.path.join(OUTPUT_DIR,'tables/gt'))
im_path=fct_misc.ensure_dir_exists(os.path.join(OUTPUT_DIR,'images/gt'))

logger.info('Reading files...')

beeches=gpd.read_file(BEECHES_POLYGONS, layer=BEECHES_LAYER)
beeches.drop(columns=['Comm', 'essence', 'diam_tronc', 'nb_tronc', 'hauteur', 'verticalit', 'diametre_c', 'mortalite_',
                'transparen', 'masse_foli', 'etat_tronc', 'etat_sanit', 'environnem',
                'microtopog', 'pente', 'remarque', 'date_leve', 'responsabl',
                'date_creat', 'vegetation', 'class_san5', 'class_san3', 'r_couronne', 'zone'], inplace=True)

chm=fct_misc.polygonize_binary_raster(CHM)
# north_chm=fct_misc.polygonize_binary_raster(NORTH_CHM)
# south_chm=fct_misc.polygonize_binary_raster(SOUTH_CHM)
# chm=pd.concat([north_chm, south_chm])
# del north_chm, south_chm

tiles=gpd.read_file(TILE_DELIMITATION)

logger.info('Retriving and formatting all the necessary information...')

if USE_FILTER:     
    fct_misc.test_crs(beeches.crs, chm.crs)
    correct_high_beeches=gpd.overlay(beeches, chm)
    correct_high_beeches.drop(columns=['class'], inplace=True)
else:
    correct_high_beeches=beeches.copy()

tiles=fct_misc.get_ortho_tiles(tiles, ORTHO_DIR, NDVI_DIR)

clipped_beeches=fct_misc.clip_labels(correct_high_beeches, tiles)

for health_class in clipped_beeches['etat_sanitaire'].unique():
    logger.info(f"There are {clipped_beeches[clipped_beeches['etat_sanitaire']==health_class].shape[0]} beeches "+
                f"with the health status '{health_class}'")

clipped_beeches=clipped_beeches[~clipped_beeches.is_empty]

logger.info('Getting the statistics of trees...')
beeches_stats=pd.DataFrame()
BANDS={1: 'rouge', 2: 'vert', 3: 'bleu', 4: 'proche IR'}
calculated_stats=['min', 'max', 'mean', 'median', 'std']

single_beeches = pd.DataFrame()
for no in tqdm(clipped_beeches.no_arbre.unique(),
                  desc='Merging double no_arbre', total=clipped_beeches.shape[0]):
    mergedPolys = unary_union(clipped_beeches[clipped_beeches.no_arbre==no].geometry)
    tmp = clipped_beeches[clipped_beeches.no_arbre==no].iloc[:1]
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
        stats_dict_rgb['no_arbre']=beech.no_arbre
        stats_dict_rgb['band']=BANDS[band_num]
        stats_dict_rgb['health_status']=beech.etat_sanitaire

        beeches_stats=pd.concat([beeches_stats, pd.DataFrame(stats_dict_rgb, index=[0])], ignore_index=True)
    
    stats_ndvi=zonal_stats(beech.geometry, beech.path_NDVI, stats=calculated_stats,
        band=1, nodata=99999)
    
    stats_dict_ndvi=stats_ndvi[0]
    stats_dict_ndvi['no_arbre']=beech.no_arbre
    stats_dict_ndvi['band']='ndvi'
    stats_dict_ndvi['health_status']=beech.etat_sanitaire

    beeches_stats=pd.concat([beeches_stats, pd.DataFrame(stats_dict_ndvi, index=[0])], ignore_index=True)

rounded_stats=beeches_stats.copy()
cols=['min', 'max', 'median', 'mean', 'std']
rounded_stats[cols]=rounded_stats[cols].round(3)

filepath=os.path.join(table_path, 'beech_stats.csv')
rounded_stats.to_csv(filepath)
written_files.append(filepath)
del rounded_stats, cols, filepath

beeches_stats.loc[beeches_stats['health_status']=='sain', 'health_status']='1. sain'
beeches_stats.loc[beeches_stats['health_status']=='malade', 'health_status']='2. malade'
beeches_stats.loc[beeches_stats['health_status']=='mort', 'health_status']='3. mort'
beeches_stats.rename(columns={'no_arbre': 'id'}, inplace=True)

beeches_stats = beeches_stats.dropna(axis=0,how='any')
for band in beeches_stats['band'].unique():
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
    to_describe='health_status'
    band_stats=beeches_stats[beeches_stats['band']==band]

    written_files_pca_pixels=pca_procedure(band_stats, features, to_describe,
                            table_path, im_path, 
                            file_prefix=f'PCA_beeches_{band}_band',
                            title_graph=f'PCA des hêtres en fonction de leur état de santé sur la bande {band}')

    written_files.extend(written_files_pca_pixels)



logger.success('Some files were written:')
for file in written_files:
    print(file)