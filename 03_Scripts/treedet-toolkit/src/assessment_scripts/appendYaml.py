import os 
#import glob
import yaml
from fnmatch import fnmatch

pathin = 'C:/Users/cmarmy/Documents/STDL/Beeches/DFT/data/output/'
pathout = 'C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/data/GPKG/'

# read folder list in
with open('C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/Liste_34_folder.txt') as f:
    name_files_in = f.readlines()

# read folder list out
with open('C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/Liste_102_folder.txt') as f:
    name_files_out = f.readlines()

# read file list out
with open('C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/Liste_102.txt') as f:
    names_out = f.readlines()

# read aoi list
with open('C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/Liste_AOI.txt') as f:
    list_aoi = f.readlines()


# loop on files YAML
# get all YAML and put them in a list
#list_YAML = glob.glob("C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/src/assessment_scripts/YAML/*.yaml")
k=0

root = 'C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/src/assessment_scripts/YAML'
pattern = "*.yaml"
list_YAML = []

for path, subdirs, files in os.walk(root):
    for name in files:
        if fnmatch(name, pattern):
            list_YAML.append(os.path.join(path, name))

for item in list_YAML:
    with open(item) as fp:
        list_doc = yaml.safe_load(fp)
        ki=0
        #list_doc['input_files']['detections'] = 'prout'
        for name in list_aoi:
            list_doc['input_files']['detections'][ki] = pathin + name_files_in[k].replace('\n','') + '/' + name.replace('\n','') + names_out[k].replace('\n','') + '.shp'
            ki += 1
        list_doc['output_files']['tagged_gt_trees'] = pathout+name_files_out[k].replace('\n','')+'_GT_charges.gpkg'
        list_doc['output_files']['tagged_detections'] = pathout +name_files_out[k].replace('\n','')+'_det_charges.gpkg'
        list_doc['output_files']['metrics'] = pathout+name_files_out[k].replace('\n','')+'_metrics.csv'
        k+=1 
        list_doc['settings']['gt_sectors_buffer_size_in_meters'] = 2
        list_doc['settings']['tolerance_in_meters'] = 2
        # list_doc['settings']['crs_dft'] = 'epsg:2056'
        
       
    # Write in YAML back
    with open(item, 'w') as file:    
        doc = yaml.dump(list_doc, file)
