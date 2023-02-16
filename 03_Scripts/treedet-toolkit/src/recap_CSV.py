#import glob 
import csv
import os
from fnmatch import fnmatch

#clear previous recapfile
recap_file = 'C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/data/recap_file_2m.csv'
if os.path.isfile(recap_file):
    os.remove(recap_file)

# get all CSV in subfolfers C:\Users\cmarmy\Documents\STDL\Beeches\treedet-toolkit-main\data put the path in a list
# list_CSV = glob.glob("C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/data/*.csv")

root = 'C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/data/GPKG'
pattern = "*.csv"
list_name = []
list_CSV = []

for path, subdirs, files in os.walk(root):
    for name in files:
        if fnmatch(name, pattern):
            list_name.append(name)
            list_CSV.append(os.path.join(path, name))

# create recap list
line_count_recap = 0;
list_ALL =  [];

for elmt in list_CSV:

    with open(elmt) as csv_file:
        csv_reader = csv.reader(csv_file, delimiter=',')
        line_count = 0
        for row in csv_reader:
            if line_count ==1 :  #get line ALL in CSV
                row.insert(0,list_name[line_count_recap])    
                list_ALL.append(row) 
                line_count_recap +=1
            line_count += 1
       
# write recap list in recap file
with open('C:/Users/cmarmy/Documents/STDL/Beeches/treedet-toolkit-main/data/recap_file_2m.csv', mode='w', newline='') as recap_file:
    recap_writer = csv.writer(recap_file, delimiter=',')
    recap_writer.writerow(['batch,sector,TP,FP,FN,p,r,f1,TP+FN,TP+FP'])
    for el in list_ALL:
        recap_writer.writerow(el)

