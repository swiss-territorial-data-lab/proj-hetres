# This script downloads the yearly NDVI variation for the AOI from 2015 to 2022
# from waldmonitoring.ch 
# Caution : the bounding box, as well as the height and width of the output image, is 
# set to fit perfectly the 10 m resolution. 

import sys
from os import chdir
from owslib.wcs import WebCoverageService

sys.path.insert(1, 'scripts')
from functions.fct_misc import ensure_dir_exists

WORKING_DIR='C:/Users/cmarmy/Documents/STDL/Beeches/delivery/proj-hetres/data'
chdir(WORKING_DIR)

output_folder = ensure_dir_exists('02_intermediate/satellite_images/ndvi_diff/')

wcs = WebCoverageService('https://geoserver.karten-werk.ch/wcs?request=GetCapabilities', version='1.0.0')

list_ndvi_diff = list(['karten-werk:wcs_ndvi_diff_2016_2015',
                       'karten-werk:wcs_ndvi_diff_2017_2016',
                       'karten-werk:wcs_ndvi_diff_2018_2017',
                       'karten-werk:wcs_ndvi_diff_2019_2018',
                       'karten-werk:wcs_ndvi_diff_2020_2019',
                       'karten-werk:wcs_ndvi_diff_2021_2020',
                       'karten-werk:wcs_ndvi_diff_2022_2021'])

for elmt in list_ndvi_diff:               
    img = wcs.getCoverage(identifier=wcs[elmt].title,bbox=(2573790,1253190, 2582990,1261500),format='image/tiff',crs='EPSG:2056', width=920, height=831)
    out = open(output_folder+wcs[elmt].title+'.tif', 'wb')
    out.write(img.read())
    out.close()