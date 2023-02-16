"""
Exploratory analysis on LAS data
"""

import os
import csv
import math
import laspy
from fnmatch import fnmatch
import numpy as np
import matplotlib.pyplot as plt
from sklearn.neighbors import KernelDensity



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


def main(PATH_IN, files_name):

    csv_recap = os.path.join(PATH_OUT, 'exploratory_recap.csv')
    list_col = ['name', 'nbr_points','height', 
                'bb_x','bb_y', 'bb_x over h', 'bb_y over h',
                'z_mean', 'z_median', 'z_mode', 
                #'z_mean_top', 'z_median_top', 'z_mode_top',
                'i_mean', 'i_median', 'i_mode', 
                #'nbr_ret_mean', 'nbr_ret_median', 'nbr_ret_mode',
                'red_mean', 'red_median', 'red_mode', 
                'blue_mean', 'blue_median', 'blue_mode',
                'green_mean', 'green_median', 'green_mode']
    with open(csv_recap, mode='w', newline='') as csv_file:
        recap_writer = csv.writer(csv_file, delimiter=',')
        recap_writer.writerow(list_col)
        csv_file.close()

    for _name in files_name:
        _las = os.path.join(PATH_IN, _name)

        with laspy.open(_las) as fh:
            # Read las data
            seg_las = fh.read()         
            n = len(seg_las.Z)


            # Compute tree height
            max_z = max(seg_las.Z)
            min_z = min(seg_las.Z)

            # LAS number format conversion
            precision = 1000000
            if max_z < 100000000:
                precision = 100000
                           
            height = float(max_z-min_z)/precision
          
            
            # X = seg_las.X.astype(float)/100
            # Y = seg_las.Y.astype(float)/10
            # Z = seg_las.Z.astype(float)/precision
            
            #C = np.array([[255, 0, 0], [0, 255, 0], [0, 0, 255]])
            #ax.scatter(X, Y, Z, c = C/255.0)
            #c=[seg_las.red,seg_las.green, seg_las.blue]
            # plt.scatter(X,Z)
            # plt.savefig(os.path.join(
            #     PATH_OUT, ('coupeX_'+_name.replace('.las', '')+'.png')))
            # plt.close()
            
            # plt.scatter(Y,Z)
            # plt.xlim(min(Y),max(Y))
            # plt.ylim(min(Z),max(Z))
            # ax = plt.gca()
            # ax.set_aspect('equal')
            # plt.draw()
            # plt.savefig(os.path.join(
            #     PATH_OUT, ('coupeY_'+_name.replace('.las', '')+'.png')))
            # plt.close()
            

            # Compute crown maximum diameter          
            # D = pdist(np.vstack((seg_las.X, seg_las.Y)).T)
            # D = squareform(D)
            # N, [I_row, I_col] = nanmax(D), unravel_index(argmax(D), D.shape)
            # diameter = N/precision
            
            # Compute Bounding Box size
            bb_x = (max(seg_las.X)-min(seg_las.X))/precision
            bb_y = (max(seg_las.Y)-min(seg_las.Y))/precision
            
            bb_x_z = bb_x / height
            bb_y_z = bb_y / height 


            # Kernel Density Function            
            Z = seg_las.Z.astype(float)/precision
            Z = Z.reshape(-1,1)
            kde = KernelDensity(kernel='gaussian', bandwidth=0.2).fit(Z)
            scores = kde.score_samples(Z)
            
            plt.scatter(Z,scores,color='red',label=_name.replace('.las', ''))
            plt.title('Kernel Density Estimation')
            plt.legend(loc="upper left")
            plt.xlabel('Z [m]')
            plt.savefig(os.path.join(
                PATH_OUT, ('KDE'+'_'+_name.replace('.las', '')+'.png')))
            plt.close()
        

            # normalized z histogram and stats
            z_mean, z_median, z_mode = norm_histogram(
                seg_las.Z, 'Z', _name, PATH_OUT, 50)
            
            # normalized top tree histogram and stats (upper half)
            Z_sort = np.sort(seg_las.Z)
            z_mean_top, z_median_top, z_mode_top = norm_histogram(
                Z_sort[math.ceil(n/2):n], 'Z_top', _name, PATH_OUT, 50)

            # intensity histogram and stats
            idx = np.argsort(seg_las.Z)
            idx_top = idx[math.ceil(n/2):n]
            
            intensity_top = seg_las.intensity[idx_top]
            
            idx_non_zero = intensity_top>0
            
            i_mean, i_median, i_mode = norm_histogram(
                intensity_top[idx_non_zero], 'intensity', _name, PATH_OUT, 50)

            # # nbr_of_return histogramm
            # nbr_max = max(seg_las.return_number)
            # nbr_mean, nbr_median, nbr_mode = norm_histogram(
            #     seg_las.return_number, 'return_number', _name, PATH_OUT, nbr_max)

            # RGB histograms and stats            
            red_mean, red_median, red_mode = norm_histogram(
              seg_las.red[idx_top], 'red', _name, PATH_OUT, 50)

            blue_mean, blue_median, blue_mode = norm_histogram(
                seg_las.blue[idx_top], 'blue', _name, PATH_OUT, 50)
            
            green_mean, green_median, green_mode = norm_histogram(
               seg_las.green[idx_top], 'green', _name, PATH_OUT, 50)

            with open(csv_recap, mode='a', newline='') as csv_file:
                recap_writer = csv.writer(csv_file, delimiter=',')
                recap_writer.writerow([_name, n, height, bb_x, bb_y, bb_x_z, bb_y_z, 
                                      z_mean, z_median, z_mode, z_mean_top, z_median_top, z_mode_top, 
                                      i_mean, i_median, i_mode, #nbr_mean, nbr_median, nbr_mode,
                                      red_mean, red_median, red_mode, blue_mean, blue_median, blue_mode,
                                      green_mean, green_median, green_mode])
                csv_file.close()


if __name__ == "__main__":
    
    # --->> TO ADAPT <<---
    PATH_IN = "C:/Users/cmarmy/Documents/STDL/Beeches/GT/GT_GT/inputs/"
    PATH_OUT = "C:/Users/cmarmy/Documents/STDL/Beeches/GT/GT_GT/outputs/"
    CUR_DIR = os.getcwd()

    root = PATH_IN
    pattern = "*.las"
    list_name = []
    list_las = []

    for path, subdirs, files in os.walk(root):
        for name in files:
            if fnmatch(name, pattern):
                list_name.append(name)
                list_las.append(os.path.join(path, name))

    main(PATH_IN, list_name)
