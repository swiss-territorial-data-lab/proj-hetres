# -*- coding: utf-8 -*-
"""
This scripts outputs a recap CSV file for height, max diameter and distributions.
It also outpus GeoTiff for profil in RGB and false color for anisotropy and linearity. 
It also gives Geotiff for the sphericity seen from the top. 

CM: for the record, KDE is very very slow within this script.. I do not know why.
Memory use ? Then use exploratory_laspy_KDE.py

"""

import os
from fnmatch import fnmatch
import math
import numpy as np
import cloudComPy as cc

import rasterio

import csv
import matplotlib.pyplot as plt


def norm_histogram(seg_las_field, name_field, name_las, PATH_OUT, nbr_bin):
    f_max = max(seg_las_field)
    f_min = min(seg_las_field)

    f_bin = np.linspace(0, 1, nbr_bin+1)

    f_norm = (seg_las_field-f_min)/(f_max-f_min).astype(np.float32)

    f_norm_hist, f_bin_hist = np.histogram(f_norm, f_bin)

    plt.hist(f_norm, f_bin,label=name_las)
    plt.title(name_field)
    plt.legend(loc="upper left")
    plt.savefig(os.path.join(
        PATH_OUT, (name_field+'_'+name_las.replace('.las', '')+'.png')))
    plt.close()

    f_mean = f_norm.mean()
    f_median = np.median(f_norm)
    f_mode_index = f_norm_hist.argmax()
    f_mode = (f_bin_hist[f_mode_index] + f_bin_hist[f_mode_index+1])/2

    return f_mean, f_median, f_mode


def geom_feature_to_tif(cloud, file_name, feature,feature_name,direction):
    # feature = feature*255
    # feature_uint8 = feature.astype('uint8')
    # feature_uint8[feature_uint8[:,0]>0,3] = 255 # canal alpha
    
    # cloud.colorsFromNPArray_copy(feature_uint8)       
    cloud.setName(file_name.replace('.las', '')+feature_name)

        
    cloud.deleteScalarField(8)
    cloud.deleteScalarField(7)
    cloud.deleteScalarField(6)
    cloud.deleteScalarField(5)
    cloud.deleteScalarField(4)
    cloud.deleteScalarField(3)
    # cc.RasterizeGeoTiffOnly(cloud, 0.1, vertDir=direction, outputRasterRGB=True, projectionType=cc.ProjectionType.PROJ_MAXIMUM_VALUE, pathToImages=PATH_OUT)
    cc.RasterizeGeoTiffOnly(cloud, 0.1, vertDir=direction, outputRasterZ=True, outputRasterSFs=True, projectionType=cc.ProjectionType.PROJ_MAXIMUM_VALUE, pathToImages=PATH_OUT)
    # in Tif
    # - band 1 = elevation
    # - band 2 = sphericity
    # - band 3 = anisotropy
    # - band 4 = linearity


def main(CC_DIR, PATH_IN, files_name, op_command):    

    csv_recap = os.path.join(PATH_OUT, 'exploratory_recap.csv')
    list_col = ['name', 'nbr_points','height', 
                'max_dist2center',
                'z_mean', 'z_median', 'z_mode', 
                #'z_mean_top', 'z_median_top', 'z_mode_top',
                'i_mean', 'i_median', 'i_mode', 
                #'nbr_ret_mean', 'nbr_ret_median', 'nbr_ret_mode',
                # 'red_mean', 'red_median', 'red_mode', 
                # 'blue_mean', 'blue_median', 'blue_mode',
                # 'green_mean', 'green_median', 'green_mode'
                ]
    with open(csv_recap, mode='w', newline='') as csv_file:
        recap_writer = csv.writer(csv_file, delimiter=',')
        recap_writer.writerow(list_col)
        csv_file.close()    
        
    for _name in files_name:
        _las = os.path.join(PATH_IN, _name)
 
        # get data
        cloud = cc.loadPointCloud(_las)
        print("cloud name: %s"%cloud.getName())   
        
        n = cloud.size()
        
        x = np.zeros(n,dtype=float)
        y = np.zeros(n,dtype=float)
        z = np.zeros(n,dtype=float)
        intensity = np.zeros(n,dtype=float)
        anisotropy = np.zeros([n, 4],dtype=float)
        linearity = np.zeros([n, 4],dtype=float)
        sphericity = np.zeros([n, 4],dtype=float)
        red = np.zeros(n,dtype=float)
        blue = np.zeros(n,dtype=float)
        green = np.zeros(n,dtype=float)
        
        red = cloud.colorsToNpArray()[:,0]
        green = cloud.colorsToNpArray()[:,1]
        blue = cloud.colorsToNpArray()[:,2]
        
        for idx in range(n):
            x[idx], y[idx], z[idx] = cloud.getPoint(idx)
            intensity[idx] = cloud.getScalarField('Intensity').getValue(idx)
            anisotropy[idx,0] = cloud.getScalarField('Anisotropy _0_4_').getValue(idx)
            linearity[idx,0] = cloud.getScalarField('Linearity _0_4_').getValue(idx)
            sphericity[idx,0] = cloud.getScalarField('Sphericity _0_4_').getValue(idx)
        #     if linearity[idx,0] <0.8:
        #         cloud.getScalarField('Linearity _0_4_').setValue(idx,-9223372036854775808)
             
        
        # bouding box computation for profil cut
        bb = cloud.getOwnBB()         
        minCorner = bb.minCorner()    
        maxCorner = bb.maxCorner() 
        bb_center = ((maxCorner[0]-minCorner[0])/2 + minCorner[0], (maxCorner[1]-minCorner[1])/2 + minCorner[1], (maxCorner[2]-minCorner[2])/2 + minCorner[2])        
        max_dist2center = math.sqrt(math.pow(((maxCorner[0]-minCorner[0])/2),2) + math.pow(((maxCorner[1]-minCorner[1])/2),2))
        Xmin = (maxCorner[0]-minCorner[0])/2 + minCorner[0] - max_dist2center
        Xmax = (maxCorner[0]-minCorner[0])/2 + minCorner[0] + max_dist2center
        Ymin = (maxCorner[1]-minCorner[1])/2 + minCorner[1] - 0.25
        Ymax = (maxCorner[1]-minCorner[1])/2 + minCorner[1] + 0.25
        minCorner_slice = (Xmin,Ymin,minCorner[2])
        maxCorner_slice = (Xmax,Ymax,maxCorner[2])
        bb_slice = cc.ccBBox(minCorner_slice,maxCorner_slice,True)
        
        
        # ---- fill recap CSV ------
        
        # Compute tree height
        max_z = max(z)
        min_z = min(z)
    
        height = max_z-min_z
        
        
        # normalized z histogram and stats
        z_mean, z_median, z_mode = norm_histogram(
            z, 'Z', _name, PATH_OUT, 50)
        
        # normalized top tree histogram and stats (upper half)
        z_sort = np.sort(z)
        z_mean_top, z_median_top, z_mode_top = norm_histogram(
            z_sort[math.ceil(n/2):n], 'Z_top', _name, PATH_OUT, 50)
        
        # intensity histogram and stats
        idx = np.argsort(z)
        idx_top = idx[math.ceil(n/2):n]
        
        intensity_top = intensity[idx_top]
        
        idx_non_zero = intensity_top>0
        
        i_mean, i_median, i_mode = norm_histogram(
            intensity_top[idx_non_zero], 'intensity', _name, PATH_OUT, 50)
        
        #RGB histograms and stats            
        red_mean, red_median, red_mode = norm_histogram(
          red[idx_top], 'red', _name, PATH_OUT, 50)
        
        blue_mean, blue_median, blue_mode = norm_histogram(
            blue[idx_top], 'blue', _name, PATH_OUT, 50)
        
        green_mean, green_median, green_mode = norm_histogram(
            green[idx_top], 'green', _name, PATH_OUT, 50)
    
        with open(csv_recap, mode='a', newline='') as csv_file:
            recap_writer = csv.writer(csv_file, delimiter=',')
            recap_writer.writerow([_name, n, height, 
                                    max_dist2center, 
                                  z_mean, z_median, z_mode, 
                                  # z_mean_top, z_median_top, z_mode_top, 
                                  i_mean, i_median, i_mode, 
                                  #nbr_mean, nbr_median, nbr_mode,
                                  # red_mean, red_median, red_mode, 
                                  # blue_mean, blue_median, blue_mode,
                                  # green_mean, green_median, green_mode
                                   ])
            csv_file.close()
        
   
        
        # cloud rotation for profil cut by bounding box
        angle = [0, np.pi/8, np.pi/4, 3*np.pi/8, np.pi/2, 5*np.pi/8, 3*np.pi/4, 7*np.pi/8]  
        
        tr1 = cc.ccGLMatrix()
        tr1.initFromParameters(
            0,
            (0.0, 0.0, 1.0),
            bb_center)
        tr1_inv = tr1.inverse() 
                
        for ang in angle:    
            
            rot1 = cc.ccGLMatrix()
            rot1.initFromParameters(
                ang, #angle to change
                (0.0, 0.0, 1.0),
                (0,0,0))
            rot1_inv = rot1.inverse()
            
            cloud.applyRigidTransformation(tr1_inv)
            cloud.applyRigidTransformation(rot1)      
            cloud.applyRigidTransformation(tr1)  
                
            res = cc.ExtractSlicesAndContours([cloud], bb_slice, processRepeatZ=False)
            
            cloud.applyRigidTransformation(tr1_inv)
            cloud.applyRigidTransformation(rot1_inv)
            cloud.applyRigidTransformation(tr1)            
                        
            res[0][0].setName(_name.replace('.las', '')+'_Profil_'+str(angle.index(ang)))
            
            cc.RasterizeGeoTiffOnly(res[0][0], 0.1, vertDir=cc.CC_DIRECTION.Y, outputRasterRGB=True, pathToImages=PATH_OUT)
            
            # cc.SavePointCloud(res[0][0], os.path.join(PATH_OUT,res[0][0].getName()+'.las'))

            # # geometric features for slices
            m = res[0][0].size()
            
            # anisotropy_slice = np.zeros([m, 4],dtype=float)
            # linearity_slice = np.zeros([m, 4],dtype=float)
            
            # for idx in range(m):
            #     anisotropy_slice[idx,0] = res[0][0].getScalarField('Anisotropy _0_4_').getValue(idx)
            #     linearity_slice[idx,0] = res[0][0].getScalarField('Linearity _0_4_').getValue(idx)
                
            # anisotropy_slice[anisotropy_slice <= 0.9] = 0
            # geom_feature_to_tif(res[0][0],res[0][0].getName(),anisotropy_slice,'_Anisotropy',cc.CC_DIRECTION.Y)
            
            # res[0][0].setName(_name.replace('.las', '')+'_Profil_'+str(angle.index(ang)))
            # linearity_slice[linearity_slice <= 0.8] = 0
            # geom_feature_to_tif(res[0][0],res[0][0].getName(),linearity_slice,'_Linearity',cc.CC_DIRECTION.Y)
            
            geom_feature_to_tif(res[0][0],res[0][0].getName(),linearity,'_AniB3_LinB4',cc.CC_DIRECTION.Y)
    
            geom_feature_to_tif(res[0][0],res[0][0].getName(),sphericity,'_SpheB2',cc.CC_DIRECTION.Z)
            
            with rasterio.open(PATH_OUT+res[0][0].getName().replace('.las','')+'_RASTER_Z_AND_SF.tif',mode="r+") as src:
                image = src.read()
                image[2,image[2,:,:]<=0.9] = float("nan")
                image[3,image[3,:,:]<=0.8] = float("nan")
                src.write(image)
                #split bands
            
        # geometric feature extraction
                       
        # anisotropy[anisotropy <= 0.9] = 0
        # geom_feature_to_tif(cloud,_name,anisotropy,'_Anisotropy',cc.CC_DIRECTION.Y)      
        # linearity[linearity <= 0.8] = 0
        # geom_feature_to_tif(cloud,_name,linearity,'_Linearity',cc.CC_DIRECTION.Y)
        
        geom_feature_to_tif(cloud,_name,linearity,'_AniB3_LinB4',cc.CC_DIRECTION.Y)
    
        # geom_feature_to_tif(cloud,_name,sphericity,'_Sphericity',cc.CC_DIRECTION.Z)
        geom_feature_to_tif(cloud,_name,sphericity,'_SpheB2',cc.CC_DIRECTION.Z)
        
        with rasterio.open(PATH_OUT+_name.replace('.las','')+'_AniB3_LinB4_RASTER_Z_AND_SF.tif',mode="r+") as src:
            image = src.read()
            image[2,image[2,:,:]<=0.9] = float("nan")
            image[3,image[3,:,:]<=0.8] = float("nan")
            src.write(image)
            #split bands


if __name__ == "__main__":
    
    # --->> TO ADAPT <<---
    op_command = [' -FEATURE ANISOTROPY 0.4 -FEATURE LINEARITY 0.4']

    # --->> TO ADAPT <<---
    PATH_IN = "C:/Users/cmarmy/Documents/STDL/Beeches/GT/GT_GT/inputs/"
    PATH_OUT = "C:/Users/cmarmy/Documents/STDL/Beeches/GT/GT_GT/outputs/"
    CC_DIR = os.path.abspath(r"C:\Program Files\CloudCompare")
    CUR_DIR = os.getcwd()

    
    pattern = "*.las"
    list_name = []
    list_las = []
    
    for path, subdirs, files in os.walk(PATH_IN):
        for name in files:
            if fnmatch(name, pattern):
                list_name.append(name)
                list_las.append(os.path.join(path, name))

    main(CC_DIR, PATH_IN, list_name, op_command)



# backup

# cloud.deleteScalarField(8)
# cloud.deleteScalarField(7)
# cloud.deleteScalarField(6)
# cloud.deleteScalarField(5)
# cloud.deleteScalarField(4)
# cloud.deleteScalarField(3)
# cloud.deleteScalarField(2)
# cloud.setName(_name.replace('.las', '')+'test')      
# cc.RasterizeGeoTiffOnly(cloud, 0.1, vertDir=cc.CC_DIRECTION.Y, outputRasterZ=True,outputRasterSFs=True, pathToImages=PATH_OUT)
