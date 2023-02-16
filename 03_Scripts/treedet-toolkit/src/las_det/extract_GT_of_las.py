import os, sys
import glob
import time
import argparse
import yaml
import numpy as np
import pandas as pd
import geopandas as gpd
import laspy

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
    detections_las: List[str]

class RequiredOutputFiles(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    tagged_gt_trees: str
    tagged_detections: str
    metrics: str
    pathOutLAS: str

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

def file_loader(file, crs):
    
    acc_gdf = gpd.GeoDataFrame() # accumulator

    #for _file in files:
        # TODO: check schema  
    tmp_gdf = gpd.read_file(file) 
    
    if tmp_gdf.crs != None:
        if tmp_gdf.crs != crs:
            logger.critical("Input datasets have mismatching CRS. Exiting.")
            sys.exit(1)
    acc_gdf = tmp_gdf

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

   
    for ind,el in enumerate(parsed_cfg.input_files.gt_sectors): #parsed_cfg.input_files.gt_sectors
        logger.info("> Loading data...")
        
        logger.info("-> GT sectors")
        gt_sectors_gdf = file_loader(parsed_cfg.input_files.gt_sectors[ind], epsg_dft)
        logger.info("<- ...done.")
    
        logger.info("-> GT trees")
        gt_trees_gdf = file_loader(parsed_cfg.input_files.gt_trees[ind], epsg_dft)
        logger.info("<- ...done.")
    
        logger.info("-> Detections")
        dets_gdf = file_loader(parsed_cfg.input_files.detections[ind], epsg_dft)
        logger.info("<- ...done.")
            
        logger.info("< ...done.")
    
        logger.info("> Pre-processing data...")
    
        buffer_size_m = parsed_cfg.settings.gt_sectors_buffer_size_in_meters
        logger.info(f"-> Adding buffer to GT sectors. Size = {buffer_size_m} m")
    
        buffered_gt_sectors_gdf = gt_sectors_gdf.copy()
        buffered_gt_sectors_gdf['geometry'] = buffered_gt_sectors_gdf.geometry.buffer(buffer_size_m)
        
        buffered_gt_trees_gdf = gt_trees_gdf.copy()
        tolerance_m = parsed_cfg.settings.tolerance_in_meters
        buffered_gt_trees_gdf['geometry'] = buffered_gt_trees_gdf.geometry.buffer(tolerance_m)
        buffered_gt_trees_gdf['sector'] = buffered_gt_trees_gdf.ID
    
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
        
        # Clip dets around GT 
    #     ? or keep the X-nearest labels?
        logger.info("-> Clipping detections using buffered GT buffered...")
        dets_gt_gdf = clip(dets_gdf, buffered_gt_trees_gdf)    
        logger.info("<- ...done.")
       
        # Extract points in LAS det for label in list.  print(np.unique(dets_las.label))
        logger.info("-> Extracting segments from LAS file...")
        #for _file in parsed_cfg.input_files.detections_las:
        with laspy.open(parsed_cfg.input_files.detections_las[ind]) as fh:
             print('Points from Header:', fh.header.point_count)
             dets_las = fh.read()
     
             for index,row in dets_gt_gdf.iterrows():
                 tree_seg = laspy.LasData(dets_las.header)
                 tree_seg.points = dets_las.points[dets_las.label == row['LUID      ']].copy()
                 tree_seg.write(str(parsed_cfg.output_files.pathOutLAS)+str(list_aoi[ind].replace('\n',''))+'_gt_'+str(row['sector'])+'_seg_'+str(int(row['LUID      ']))+'.las')
        logger.info("<- ...done.")    
        
        toc = time.time()
        logger.info(f"...done in {toc-tic:.2f} seconds.")


if __name__ == "__main__":

# =============================================================================
#     parser = argparse.ArgumentParser(description="This script assesses the quality of detections with respect to ground-truth data.")
#     parser.add_argument('config_file', type=str, help='a YAML config file')
#     args = parser.parse_args()
# 
#     main(args.config_file)
# =============================================================================

    with open('C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/Liste_AOI.txt') as f:
        list_aoi = f.readlines()

    list_YAML = glob.glob("C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/src/las_det/*.yaml")
  
    for YAML_file in list_YAML:
        main(YAML_file)
        
