# This script downloads the yearly NDVI difference for the AOI from 2015 to 2022
# from waldmonitoring.ch 
# Caution : the bounding box, as well as the height and width of the output image, is 
# set to fit perfectly the 10 m resolution. 

import sys
from os import chdir
from owslib.wcs import WebCoverageService

sys.path.insert(1, 'scripts')
from functions.fct_misc import ensure_dir_exists

WORKING_DIR='C:/Users/gwena/Documents/STDL/2_En_cours/deperissement-hetres/02_Data'
chdir(WORKING_DIR)

output_folder = ensure_dir_exists('02_intermediate/satellite_images/ndvi_diff/')

wcs = WebCoverageService('https://geoserver.karten-werk.ch/wcs?request=GetCapabilities', version='1.0.0')

list_ndvi_diff = list(wcs.contents)[19:26]

for elmt in list_ndvi_diff:               
    img = wcs.getCoverage(identifier=wcs[elmt].title,bbox=(2573790,1253190, 2582990,1261500),format='image/tiff',crs='EPSG:2056', width=920, height=831)
    out = open(output_folder+wcs[elmt].title+'.tif', 'wb')
    out.write(img.read())
    out.close()