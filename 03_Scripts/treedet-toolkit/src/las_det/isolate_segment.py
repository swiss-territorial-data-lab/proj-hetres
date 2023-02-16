# -*- coding: utf-8 -*-
"""
Created on Fri Dec 30 09:21:41 2022

@author: cmarmy
"""

# read LAS sector

# iterate for each labeled segment

# save in separate LAS

# save as a picture

import os, sys
import time
import yaml
import laspy
import cloudComPy as cc

from logzero import logger
from pydantic import BaseModel
from typing import List



class RequiredInputFiles(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    gt_sectors: List[str]
    acquisitions_las: List[str]
    detections_las: List[str]

class RequiredOutputFiles(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    pathOutLAS: str

class RequiredSettings(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    crs_dft: str

class Configuration(BaseModel):

    class Config:
        # cf. https://pydantic-docs.helpmanual.io/usage/model_config/
        extra = 'forbid'

    input_files: RequiredInputFiles
    output_files: RequiredOutputFiles
    settings: RequiredSettings



def main(config_file):

    tic = time.time()
    
    logger.info("Starting...")
   
    logger.info("> Loading configuration file...")
   
    with open(config_file) as fp:
        cfg = yaml.load(fp, Loader=yaml.FullLoader)#[os.path.basename(__file__)]
    logger.info("< ...done.")

    logger.info("> Parsing configuration...")
    parsed_cfg = Configuration(**cfg)
    
    epsg_dft = parsed_cfg.settings.crs_dft
       
    logger.info("< ...done.")

   
    for ind,el in enumerate(parsed_cfg.input_files.gt_sectors): 
  
        logger.info("-> Extracting segments from LAS file...")
        
        with laspy.open(parsed_cfg.input_files.detections_las[ind]) as fh:
             print('Points from Header:', fh.header.point_count)
             dets_las = fh.read()
        with laspy.open(parsed_cfg.input_files.acquisitions_las[ind]) as fh:
             print('Points from Header:', fh.header.point_count)
             acq_las = fh.read()
             
        for label in range(1,max(dets_las.label),1):
            tree_seg = laspy.LasData(acq_las.header)
            tree_seg.points = acq_las.points[dets_las.label == label].copy()
            tree_seg.write(str(parsed_cfg.output_files.pathOutLAS)+str(list_aoi[ind].replace('\n',''))+'_seg_'+str(label)+'.las')
            tree = cc.loadPointCloud(str(parsed_cfg.output_files.pathOutLAS)+str(list_aoi[ind].replace('\n',''))+'_seg_'+str(label)+'.las')
            tree.setName(str(list_aoi[ind].replace('\n',''))+'_seg_'+str(label)+'_X')
            cc.RasterizeGeoTiffOnly(tree, 0.1, vertDir=cc.CC_DIRECTION.X, outputRasterRGB=True, pathToImages=str(parsed_cfg.output_files.pathOutLAS))
            tree.setName(str(list_aoi[ind].replace('\n',''))+'_seg_'+str(label)+'_Y')
            cc.RasterizeGeoTiffOnly(tree, 0.1, vertDir=cc.CC_DIRECTION.Y, outputRasterRGB=True, pathToImages=str(parsed_cfg.output_files.pathOutLAS))

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

    #list_YAML = glob.glob("C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/src/las_det/*.yaml")
  
    # for YAML_file in list_YAML:
    #     main(YAML_file)
    
    main("C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/src/las_det/separate_seg.yml")
        
