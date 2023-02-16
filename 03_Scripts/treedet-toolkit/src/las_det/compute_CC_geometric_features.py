# -*- coding: utf-8 -*-
"""
This script computes geometric features (linearity, anisotropy and geometry) 
for each point and its neighborhood in a point cloud. 

The script writes the command lines and makes them be executed by Windows system.
"""

import os
import subprocess as sp
import multiprocessing as mp


def launchComm(commandString):
    sp.call(str(commandString),shell=True)


if __name__ == '__main__':
    
    # --->> TO ADAPT <<---
    input_CCBin = os.path.abspath(r"C:\Program Files\CloudCompare")
    PATH_IN = "C:/Users/cmarmy/Documents/STDL/Beeches/GT/GT_GT/inputs/"
    PATH_OUT = "C:/Users/cmarmy/Documents/STDL/Beeches/GT/GT_GT/inputs/"
    
    input_folder_las = os.path.abspath(PATH_IN)
    input_las = os.listdir(input_folder_las)  
    
    output_dir = os.path.abspath(PATH_OUT)
    
    num_process = mp.cpu_count()-2
    
    all_command = []
    op_command = [' -FEATURE ANISOTROPY 0.4',' -FEATURE LINEARITY 0.4', ' -FEATURE SPHERICITY 0.4']

    # build the commands
    for op in op_command:
        for k in range(len(input_las)):
            if os.path.exists(os.path.join(input_folder_las,input_las[k])):
                executable_str = '"'+ os.path.join(input_CCBin,"CloudCompare.exe") +'"'
                in_files_comm = str(os.path.join(input_folder_las,input_las[k]))
                output_comm = ' -C_EXPORT_FMT LAS -SAVE_CLOUDS FILE "' + str(output_dir)+'\\'+input_las[k]+'"'
                command_all = executable_str + ' -SILENT -AUTO_SAVE OFF -O -GLOBAL_SHIFT AUTO ' + in_files_comm + op + output_comm
                all_command.append(command_all)
    
    # execute the commands
    mp.freeze_support()       
    p = mp.Pool(num_process)
    p.map(launchComm, all_command)