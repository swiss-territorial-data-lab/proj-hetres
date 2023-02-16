from lib2to3.pgen2.token import LEFTSHIFTEQUAL
import os, sys
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

    run_A_detections: List[str]
    run_B_detections: List[str]

class RequiredOutputFiles(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    matched_run_A_detections: str
    matched_run_B_detections: str
    unmatched_run_A_detections: str
    unmatched_run_B_detections: str

class RequiredSettings(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    #gt_sectors_buffer_size_in_meters: float
    tolerance_in_meters: float

class Configuration(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    input_files: RequiredInputFiles
    output_files: RequiredOutputFiles
    settings: RequiredSettings

def file_loader(files):

    acc_gdf = gpd.GeoDataFrame() # accumulator

    crs = None # init
    for _file in files:
        # TODO: check schema  
        tmp_gdf = gpd.read_file(_file) 
        if crs is None:
            crs = tmp_gdf.crs
        else:
            if tmp_gdf.crs != crs:
                logger.critical("Input datasets have mismatching CRS. Exiting.")
                sys.exit(1)
        acc_gdf = pd.concat([acc_gdf, tmp_gdf])

    gdf = gpd.GeoDataFrame(acc_gdf)
    gdf = gdf.set_crs(crs)

    return gdf.reset_index(drop=True)

# def add_geohash(gdf, prefix=None, suffix=None):

#     out_gdf = gdf.copy()
#     out_gdf['geohash'] = gdf.to_crs(epsg=4326).apply(geohash, axis=1)

#     if prefix is not None:
#         out_gdf['geohash'] = prefix + out_gdf['geohash'].astype(str)

#     if suffix is not None:
#         out_gdf['geohash'] = out_gdf['geohash'].astype(str) + suffix

#     return out_gdf

# def drop_duplicates(gdf):
    
#     out_gdf = gdf.copy()
#     out_gdf.drop_duplicates(subset='geohash', inplace=True)

#     return out_gdf
    

def main(config_file):

    tic = time.time()
    logger.info("Starting...")
   
    logger.info("> Loading configuration file...")
    with open(config_file) as fp:
        cfg = yaml.load(fp, Loader=yaml.FullLoader)#[os.path.basename(__file__)]
    logger.info("< ...done.")

    logger.info("> Parsing configuration...")
    parsed_cfg = Configuration(**cfg)
    logger.info("< ...done.")

    logger.info("> Loading data...")
    
    gdf = {}

    logger.info("-> Detections from run A...")
    gdf['A'] = file_loader(parsed_cfg.input_files.run_A_detections)
    logger.info("<- ...done.")

    logger.info("-> Detections from run B...")
    gdf['B'] = file_loader(parsed_cfg.input_files.run_B_detections)
    logger.info("<- ...done.")
 
    logger.info("-> Checking whether input datasets share the same CRS...")
    assert gdf['A'].crs == gdf['B'].crs
    logger.info("<- ...done.")

    logger.info("< ...done.")

    logger.info("> Pre-processing data...")

    _gdf = {}
    for k, v in gdf.items():
        tmp = v.copy()
        tmp['geometry'] = tmp['geometry'].centroid.buffer(parsed_cfg.settings.tolerance_in_meters / 2.0)
        tmp = tmp.reset_index()
        tmp = tmp.rename(columns={"index": 'idx'})
        _gdf[k] = tmp.copy()
        del tmp

    logger.info("< ..done.")

    logger.info("> Finding matches...")
    ljoin = gpd.sjoin(_gdf["A"], _gdf["B"], how='left',  op='intersects', lsuffix='x', rsuffix='y')
    rjoin = gpd.sjoin(_gdf["A"], _gdf["B"], how='right', op='intersects', lsuffix='x', rsuffix='y')
    

    _gdf['A_matched'] = ljoin[ljoin.idx_y.notnull()].copy()
    _gdf['A_unmatched'] = ljoin[ljoin.idx_y.isna()].copy()

    _gdf['B_matched'] = rjoin[rjoin.idx_x.notnull()].copy()
    _gdf['B_unmatched'] = rjoin[rjoin.idx_x.isna()].copy()
    logger.info("< ...done.")

    logger.info("> Dropping duplicates...")

    _gdf['A_matched'].drop_duplicates(subset=gdf['A'].columns.tolist(), inplace=True)
    _gdf['A_unmatched'].drop_duplicates(subset=gdf['A'].columns.tolist(), inplace=True)
    _gdf['B_matched'].drop_duplicates(subset=gdf['B'].columns.tolist(), inplace=True)
    _gdf['B_unmatched'].drop_duplicates(subset=gdf['B'].columns.tolist(), inplace=True)

    logger.info("< ...done.")

    logger.info("> Checking counts...")
    assert len(_gdf['A_matched']) + len(_gdf['A_unmatched']) == len(gdf['A'])
    assert len(_gdf['B_matched']) + len(_gdf['B_unmatched']) == len(gdf['B'])
    logger.info("< ...done.")


    logger.info(f"Run A detections split as follows: {len(_gdf['A_matched'])} (matched) + {len(_gdf['A_unmatched'])} (unmatched) = {len(gdf['A'])}")
    logger.info(f"Run B detections split as follows: {len(_gdf['B_matched'])} (matched) + {len(_gdf['B_unmatched'])} (unmatched) = {len(gdf['B'])}")

    logger.info("> Generating output files...")

    # Extracting centroids
    for k, v in _gdf.items():
        v['geometry'] = v['geometry'].centroid

    _gdf['A_matched'][gdf['A'].columns].to_file(parsed_cfg.output_files.matched_run_A_detections, driver='GPKG')
    _gdf['B_matched'][gdf['B'].columns].to_file(parsed_cfg.output_files.matched_run_B_detections, driver='GPKG')
    _gdf['A_unmatched'][gdf['A'].columns].to_file(parsed_cfg.output_files.unmatched_run_A_detections, driver='GPKG')
    _gdf['B_unmatched'][gdf['B'].columns].to_file(parsed_cfg.output_files.unmatched_run_B_detections, driver='GPKG')
    
    logger.info("< ...done. The following files were generated:")
    for out_file in parsed_cfg.output_files:
        logger.info(out_file[1])
    
    toc = time.time()
    logger.info(f"...done in {toc-tic:.2f} seconds.")


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="This script finds matched between detections coming from two different runs.")
    parser.add_argument('config_file', type=str, help='a YAML config file')
    args = parser.parse_args()

    main(args.config_file)