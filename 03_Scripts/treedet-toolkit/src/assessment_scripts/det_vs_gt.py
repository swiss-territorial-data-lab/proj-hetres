import os, sys
import glob
import time
import argparse
import yaml
import pandas as pd
import geopandas as gpd

from logzero import logger
from pydantic import BaseModel
from typing import List

# the following lines allow us to import modules from within this file's parent folder
from inspect import getsourcefile
current_path = os.path.abspath(getsourcefile(lambda:0))
current_dir = os.path.dirname(current_path)
parent_dir = current_dir[:current_dir.rfind(os.path.sep)]
sys.path.insert(0, parent_dir)
from lib.misc import geohash, clip, tag, assess


class RequiredInputFiles(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    gt_sectors: List[str]
    gt_trees: List[str]
    detections: List[str]

class RequiredOutputFiles(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    tagged_gt_trees: str
    tagged_detections: str
    metrics: str

class RequiredSettings(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    gt_sectors_buffer_size_in_meters: float
    tolerance_in_meters: float
    crs_dft: str

class Configuration(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    input_files: RequiredInputFiles
    output_files: RequiredOutputFiles
    settings: RequiredSettings

def file_loader(files, crs):
    
    acc_gdf = gpd.GeoDataFrame() # accumulator

    for _file in files:
        # TODO: check schema  
        tmp_gdf = gpd.read_file(_file) 
        
        if tmp_gdf.crs != None:
            if tmp_gdf.crs != crs:
                logger.critical("Input datasets have mismatching CRS. Exiting.")
                sys.exit(1)
        acc_gdf = pd.concat([acc_gdf, tmp_gdf])

    gdf = gpd.GeoDataFrame(acc_gdf)
    gdf = gdf.set_crs(crs)

    return gdf.reset_index(drop=True)

def add_geohash(gdf, prefix=None, suffix=None):

    out_gdf = gdf.copy()
    out_gdf['geohash'] = gdf.to_crs(epsg=4326).apply(geohash, axis=1)

    if prefix is not None:
        out_gdf['geohash'] = prefix + out_gdf['geohash'].astype(str)

    if suffix is not None:
        out_gdf['geohash'] = out_gdf['geohash'].astype(str) + suffix

    return out_gdf

def drop_duplicates(gdf):
    
    out_gdf = gdf.copy()
    out_gdf.drop_duplicates(subset='geohash', inplace=True)

    return out_gdf
    


def main(config_file):

    tic = time.time()
    
    logger.info("Starting...")
   
    logger.info("> Loading configuration file...")
   
    with open(config_file) as fp:
        cfg = yaml.load(fp, Loader=yaml.FullLoader)#[os.path.basename(__file__)]
    logger.info("< ...done.")

    logger.info("> Parsing configuration...")
    parsed_cfg = Configuration(**cfg)
    
#    global epsg_dft 
    epsg_dft = parsed_cfg.settings.crs_dft
    
    
    logger.info("< ...done.")

    logger.info("> Loading data...")
    
    logger.info("-> GT sectors")
    gt_sectors_gdf = file_loader(parsed_cfg.input_files.gt_sectors, epsg_dft)
    logger.info("<- ...done.")

    logger.info("-> GT trees")
    gt_trees_gdf = file_loader(parsed_cfg.input_files.gt_trees, epsg_dft)
    logger.info("<- ...done.")

    logger.info("-> Detections")
    dets_gdf = file_loader(parsed_cfg.input_files.detections, epsg_dft)
    logger.info("<- ...done.")
    
    logger.info("< ...done.")

    logger.info("> Pre-processing data...")

    buffer_size_m = parsed_cfg.settings.gt_sectors_buffer_size_in_meters
    logger.info(f"-> Adding buffer to GT sectors. Size = {buffer_size_m} m")

    buffered_gt_sectors_gdf = gt_sectors_gdf.copy()
    buffered_gt_sectors_gdf['geometry'] = buffered_gt_sectors_gdf.geometry.buffer(buffer_size_m)

    logger.info("<- ...done.")

    logger.info("-> Geohashing GT trees...")
    GT_PREFIX= 'gt_'
    gt_trees_gdf = add_geohash(gt_trees_gdf, prefix=GT_PREFIX)
    logger.info("<- ...done.")

    logger.info("-> Dropping duplicates in GT trees...")
    gt_trees_gdf = drop_duplicates(gt_trees_gdf)
    logger.info("<- ...done.")

    logger.info("-> Geohashing detections...")
    DETS_PREFIX = "dt_"
    dets_gdf = add_geohash(dets_gdf, prefix=DETS_PREFIX)
    logger.info("<- ...done.")

    logger.info("-> Dropping duplicates in detections...")
    dets_gdf = drop_duplicates(dets_gdf)
    logger.info("<- ...done.")
    
    logger.info("-> Clipping GT trees using buffered GT sectors...")
    gt_trees_gdf = clip(gt_trees_gdf, buffered_gt_sectors_gdf)
    logger.info("<- ...done.")

    logger.info("-> Clipping detections using buffered GT sectors...")
    dets_gdf = clip(dets_gdf, buffered_gt_sectors_gdf)
    logger.info("<- ...done.")
    logger.info("< ...done.")

    logger.info("> Assessing detections...")
    logger.info("-> Tagging GT trees and detections (True Positives, False Positives, False Negatives)...")
    tolerance_m = parsed_cfg.settings.tolerance_in_meters
    tagged_gt_gdf, tagged_dets_gdf = tag(gt=gt_trees_gdf, dets=dets_gdf, tol_m=tolerance_m, gt_prefix=GT_PREFIX, dets_prefix=DETS_PREFIX)
    logger.info("<- ...done.")

    logger.info("-> Computing metrics...")

    metrics_df = pd.DataFrame()

    logger.info("--> Global metrics")
    metrics = assess(tagged_gt_gdf, tagged_dets_gdf)

    tmp_df = pd.DataFrame.from_records([{'sector': 'ALL', **metrics}])
    metrics_df = pd.concat([metrics_df, tmp_df])

    logger.info("<-- ...done.")

    logger.info("--> Per sector metrics")
    for sector in sorted(gt_sectors_gdf.sector.unique()):
        metrics = assess(
            tagged_gt = tagged_gt_gdf[tagged_gt_gdf.sector == sector],
            tagged_dets = tagged_dets_gdf[tagged_dets_gdf.sector == sector],
        )
        tmp_df = pd.DataFrame.from_records([{'sector': sector, **metrics}])
        metrics_df = pd.concat([metrics_df, tmp_df])

    logger.info("<-- ...done.")
    logger.info("<- ...done.")
    logger.info("< ...done.")

    logger.info("> Generating output files...")
    tagged_gt_gdf.astype({'TP_charge': 'str', 'FN_charge': 'str'}).to_file(parsed_cfg.output_files.tagged_gt_trees, driver='GPKG')
    tagged_dets_gdf.astype({'TP_charge': 'str', 'FP_charge': 'str'}).to_file(parsed_cfg.output_files.tagged_detections, driver='GPKG')
    metrics_df.to_csv(parsed_cfg.output_files.metrics, sep=',', index=False)
    logger.info("< ...done. The following files were generated:")
    for out_file in parsed_cfg.output_files:
        logger.info(out_file[1])
    
    toc = time.time()
    logger.info(f"...done in {toc-tic:.2f} seconds.")

    print()
    print("Metrics:")
    print(metrics_df)


if __name__ == "__main__":

# =============================================================================
#     parser = argparse.ArgumentParser(description="This script assesses the quality of detections with respect to ground-truth data.")
#     parser.add_argument('config_file', type=str, help='a YAML config file')
#     args = parser.parse_args()
# 
#     main(args.config_file)
# =============================================================================

# iterate through all parameter's configuration tested. 

    list_YAML = glob.glob("C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/src/assessment_scripts/YAML/*.yaml")
    
    for YAML_file in list_YAML:
        main(YAML_file)
        
