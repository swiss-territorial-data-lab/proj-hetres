# This script subsamples an LiDAR point cloud (LAS format) for a factor of 5 (can be changed in scripts).
# It outputs the corresponding subsampled LAS files to the input files. 

import os
import laspy
from fnmatch import fnmatch
import numpy as np

############################### INPUTS #########################################
#   DIR_IN : input directory with LAS files
#   DIR_OUT : directory for output files

WORKING_DIR='C:/Users/gwena/Documents/STDL/2_En_cours/deperissement-hetres/02_Data'
os.chdir(WORKING_DIR)

PATH_IN = "01_initial/lidar_point_cloud/original"
PATH_OUT = "02_intermediate/lidar_point_cloud/downsampled"
 
################################################################################

def main(PATH_IN, files_name):

    factor = 5
    
    for _name in files_name:
        _las = os.path.join(PATH_IN, _name)

        with laspy.open(_las) as fh:
            # Read las data
            las = laspy.read(fh)
        tree_seg = laspy.LasData(las.header)
        tree_seg.points = las.points[::factor].copy()

        tree_seg.write(os.path.join(PATH_OUT,_name))      


if __name__ == "__main__":
    
    # --->> TO ADAPT <<---
    CUR_DIR = os.getcwd()

    pattern = "*.las"
    list_name = []
    list_las = []

    for files in os.walk(PATH_IN).next()[2]:
        for name in files:
            if fnmatch(name, pattern):
                list_name.append(name)
                list_las.append(os.path.join(PATH_IN, name))

    main(PATH_IN, list_name)