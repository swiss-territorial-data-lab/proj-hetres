# This script subsamples an LiDAR point cloud (LAS format) for a factor of 5 (can be changed in scripts).
# It outputs the corresponding subsampled LAS files to the input files. 

import os, sys
import laspy
from fnmatch import fnmatch
from loguru import logger

sys.path.insert(1, 'scripts')
import functions.fct_misc as fct_misc

logger=fct_misc.format_logger(logger)

############################### INPUTS #########################################
#   DIR_IN : input directory with LAS files
#   DIR_OUT : directory for output files

WORKING_DIR='C:/Users/gwena/Documents/STDL/2_En_cours/deperissement-hetres/02_Data'
os.chdir(WORKING_DIR)

PATH_IN = "01_initial/lidar_point_cloud/original"
PATH_OUT = fct_misc.ensure_dir_exists("02_intermediate/lidar_point_cloud/downsampled")
 
################################################################################

def main(path_in, path_out, files_name):

    factor = 5
    
    for _name in files_name:
        _las = os.path.join(path_in, _name)

        with laspy.open(_las) as fh:
            # Read las data
            las = fh.read()
        tree_seg = laspy.LasData(las.header)
        tree_seg.points = las.points[::factor].copy()

        tree_seg.write(os.path.join(path_out, _name)) 


if __name__ == "__main__":

    # --->> TO ADAPT <<---
    pattern = "*.las"
    list_name = []

    logger.info('Finding all the relevant files...')
    for _, _, files in os.walk(PATH_IN):
        for name in files:
            if fnmatch(name, pattern):
                list_name.append(name)

    logger.info(f'Found {len(list_name)} files to subsample.')
    logger.info(f'Subsampling files...')
    main(PATH_IN, PATH_OUT, list_name)

    logger.success(f'The new files were written in the folder {PATH_OUT}.')