import sys
import os

import geopandas as gpd
import pandas as pd
from shapely.geometry import mapping, shape
from shapely.affinity import scale

import rasterio
from rasterio.mask import mask
from rasterio.features import shapes

import numpy as np


def format_logger(logger):
    logger.remove()
    logger.add(sys.stderr, format="{time:YYYY-MM-DD HH:mm:ss} - {level} - {message}",
            level="INFO", filter=lambda record: record["level"].no < 25)
    logger.add(sys.stderr, format="{time:YYYY-MM-DD HH:mm:ss} - <green>{level}</green> - {message}",
            level="SUCCESS", filter=lambda record: record["level"].no < 30)
    logger.add(sys.stderr, format="{time:YYYY-MM-DD HH:mm:ss} - <yellow>{level}</yellow> - {message}",
            level="WARNING", filter=lambda record: record["level"].no < 40)
    logger.add(sys.stderr, format="{time:YYYY-MM-DD HH:mm:ss} - <red>{level}</red> - <level>{message}</level>",
            level="ERROR")
    return logger

def test_crs(crs1, crs2 = "EPSG:2056"):
    '''
    Take the crs of two dataframes and compare them. If they are not the same, stop the script.
    '''
    if isinstance(crs1, gpd.GeoDataFrame):
        crs1=crs1.crs
    if isinstance(crs2, gpd.GeoDataFrame):
        crs2=crs2.crs

    try:
        assert(crs1 == crs2), f"CRS mismatch between the two files ({crs1} vs {crs2})."
    except Exception as e:
        print(e)
        sys.exit(1)

def ensure_dir_exists(dirpath):
    '''
    Test if a directory exists. If not, make it.

    return: the path to the verified directory.
    '''

    if not os.path.exists(dirpath):
        os.makedirs(dirpath)
        print(f"The directory {dirpath} was created.")

    return dirpath


def get_pixel_values(geoms, tile, bands = range(1,4), pixel_values = pd.DataFrame(), **kwargs):
    '''
    Extract the value of the raster pixels falling under the mask and save them in a dataframe.
    cf https://gis.stackexchange.com/questions/260304/extract-raster-values-within-shapefile-with-pygeoprocessing-or-gdal

    - geoms: list of shapely geometries determining the zones where the pixels are extracted
    - tile: path to the raster image
    - bands: bands of the tile
    - pixel_values: dataframe to which the values for the pixels are going to be concatenated
    - kwargs: additional arguments we would like to pass the dataframe of the pixels

    return: a dataframe with the pixel values on each band and the keyworded arguments.
    '''
    
    # extract the geometry in GeoJSON format
    geoms_list = [mapping(geoms)]

    # extract the raster values values within the polygon 
    with rasterio.open(tile) as src:
        # test_crs(geoms.crs, src.crs)
        # print('Same crs')
        out_image, _ = mask(src, geoms_list, crop=True)
        # out_image, _ = mask(src, geoms_list, crop=True, filled=False)

        # no data values of the original raster
        no_data=src.nodata
    
    dico={}
    length_bands=[]
    for band in bands:

        # extract the values of the masked array
        data = out_image[band-1]

        # extract the the valid values
        val = np.extract(data != no_data, data)
        # val = np.extract(~data.mask, data.data)

        dico[f'band{band}']=val
        length_bands.append(len(val))

    max_length=max(length_bands)

    for band in bands:

        if length_bands[band-1] < max_length:

            fill=[no_data]*max_length
            dico[f'band{band}']=np.append(dico[f'band{band}'], fill[length_bands[band-1]:])

            print(f'{max_length-length_bands[band-1]} pixels was/were missing on the band {band} on the tile {tile[-18:]} and' +
                        f' got replaced with the value used of no data ({no_data}).')

    dico.update(**kwargs)
    pixels_from_tile = pd.DataFrame(dico)

    # We consider that the nodata values are where the value is 0 on each band
    if no_data is None:
        subset=pixels_from_tile[[f'band{band}' for band in bands]]
        pixels_from_tile = pixels_from_tile.drop(pixels_from_tile[subset.apply(lambda x: (max(x) == 0), 1)].index)

    pixel_values = pd.concat([pixel_values, pixels_from_tile],ignore_index=True)

    return pixel_values


def polygons_diff_without_artifacts(polygons, p1_idx, p2_idx, keep_everything=False):
    '''
    Make the difference of the geometry at row p2_idx with the one at the row p1_idx
    
    - polygons: dataframe of polygons
    - p1_idx: index of the "obstacle" polygon in the dataset
    - p2_idx: index of the final polygon
    - keep_everything: boolean indicating if we should keep large parts that would be eliminated otherwise

    return: a dataframe of the polygons where the part of p1_idx overlapping with p2_idx has been erased. The parts of
    multipolygons can be all kept or just the largest one (longer process).
    '''
    
    # Store intermediary results back to poly
    diff=polygons.loc[p2_idx,'geometry']-polygons.loc[p1_idx,'geometry']

    if diff.geom_type == 'Polygon':
        polygons.loc[p2_idx,'geometry'] -= polygons.loc[p1_idx,'geometry']

    elif diff.geom_type == 'MultiPolygon':
        # if a multipolygone is created, only keep the largest part to avoid the following error: https://github.com/geopandas/geopandas/issues/992
        polygons.loc[p2_idx,'geometry'] = max((polygons.loc[p2_idx,'geometry']-polygons.loc[p1_idx,'geometry']).geoms, key=lambda a: a.area)

        # The threshold to which we consider that subparts are still important is hard-coded at 10 units.
        limit=10
        parts_geom=[poly for poly in diff.geoms if poly.area>limit]
        if len(parts_geom)>1 and keep_everything:
            parts_area=[poly.area for poly in diff.geoms if poly.area>limit]
            parts=pd.DataFrame({'geometry':parts_geom,'area':parts_area})
            parts.sort_values(by='area', ascending=False, inplace=True)
            
            new_row_serie=polygons.loc[p2_idx].copy()
            new_row_dict={'OBJECTID': [], 'OBJEKTART': [], 'KUNSTBAUTE': [], 'BELAGSART': [], 'geometry': [], 
                        'GDB-Code': [], 'Width': [], 'saved_geom': []}
            new_poly=0
            for elem_geom in parts['geometry'].values[1:]:
                
                new_row_dict['OBJECTID'].append(int(str(int(new_row_serie.OBJECTID))+str(new_poly)))
                new_row_dict['geometry'].append(elem_geom)
                new_row_dict['OBJEKTART'].append(new_row_serie.OBJEKTART)
                new_row_dict['KUNSTBAUTE'].append(new_row_serie.KUNSTBAUTE)
                new_row_dict['BELAGSART'].append(new_row_serie.BELAGSART)
                new_row_dict['GDB-Code'].append(new_row_serie['GDB-Code'])
                new_row_dict['Width'].append(new_row_serie.Width)
                new_row_dict['saved_geom'].append(new_row_serie.saved_geom)

                new_poly+=1

            polygons=pd.concat([polygons, pd.DataFrame(new_row_dict)], ignore_index=True)

    return polygons


def test_valid_geom(poly_gdf, correct=False, gdf_obj_name=None):
    '''
    Test if all the geometry of a dataset are valid. When it is not the case, correct the geometries with a buffer of 0 m
    if correct != False and stop with an error otherwise.

    - poly_gdf: dataframe of geometries to check
    - correct: boolean indicating if the invalid geometries should be corrected with a buffer of 0 m
    - gdf_boj_name: name of the dataframe of the object in it to print with the error message

    return: a dataframe with only valid geometries.
    '''

    try:
        assert(poly_gdf[poly_gdf.is_valid==False].shape[0]==0), \
            f"{poly_gdf[poly_gdf.is_valid==False].shape[0]} geometries are invalid {f' among the {gdf_obj_name}' if gdf_obj_name else ''}."
    except Exception as e:
        print(e)
        if correct:
            print("Correction of the invalid geometries with a buffer of 0 m...")
            corrected_poly=poly_gdf.copy()
            corrected_poly.loc[corrected_poly.is_valid==False,'geometry']= \
                            corrected_poly[corrected_poly.is_valid==False]['geometry'].buffer(0)

            return corrected_poly
        else:
            sys.exit(1)

    print(f"There aren't any invalid geometries{f' among the {gdf_obj_name}' if gdf_obj_name else ''}.")

    return poly_gdf


def polygonize_binary_raster(path):
    '''
    Get a binary raster and return a dataframe of the zones equal to 1.

    -path: path to the binary raster.
    return: a dataframe of the pixels equal to 1 aggregated into polygons.
    '''

    with rasterio.open(path) as src:
        image=src.read(1)

        mask= image==1
        geoms = ((shape(s), v) for s, v in shapes(image, mask, transform=src.transform))
        gdf=gpd.GeoDataFrame(geoms, columns=['geometry', 'class'])
        gdf.set_crs(crs=src.crs, inplace=True)

    return gdf


def clip_labels(labels_gdf, tiles_gdf, fact=0.99):
    '''
    Clip the labels to the tiles
    Copied from the misc functions of the object detector 
    cf. https://github.com/swiss-territorial-data-lab/object-detector/blob/master/helpers/misc.py

    - labels_gdf: geodataframe with the labels
    - tiles_gdf: geodataframe of the tiles
    - fact: factor to scale the tiles before clipping
    return: a geodataframe with the labels clipped to the tiles
    '''

    tiles_gdf['tile_geometry'] = tiles_gdf['geometry']
        
    assert(labels_gdf.crs.name == tiles_gdf.crs.name)
    
    labels_tiles_sjoined_gdf = gpd.sjoin(labels_gdf, tiles_gdf, how='inner', predicate='intersects')
    
    def clip_row(row, fact=fact):
        
        old_geo = row.geometry
        scaled_tile_geo = scale(row.tile_geometry, xfact=fact, yfact=fact)
        new_geo = old_geo.intersection(scaled_tile_geo)
        row['geometry'] = new_geo

        return row

    clipped_labels_gdf = labels_tiles_sjoined_gdf.apply(lambda row: clip_row(row, fact), axis=1)
    clipped_labels_gdf.crs = labels_gdf.crs

    clipped_labels_gdf.drop(columns=['tile_geometry', 'index_right'], inplace=True)
    clipped_labels_gdf.rename(columns={'id': 'tile_id'}, inplace=True)

    return clipped_labels_gdf

def get_ortho_tiles(tiles, FOLDER_PATH_IN, FOLDER_PATH_OUT, WORKING_DIR=None):
    '''
    Get the true orthorectified tiles and the corresponding NDVI file based on the tile name.

    - tiles: dataframe of with the delimitation and the id of the file.
    - PATH_ORIGINAL: path to the original tiles
    - PATH_NDVI: path to the NDVI tiles
    - WORKING_DIR: working directory to be set (if needed)
    return: the tile dataframe with an additional field with the path to each file.
    '''

    if WORKING_DIR:
        os.chdir(WORKING_DIR)

    rgb_pathes=[]
    ndvi_pathes=[]

    for tile_name in tiles['NAME'].values:
                                       
        rgb_pathes.append(os.path.join(FOLDER_PATH_IN, tile_name + '.tif'))
        ndvi_pathes.append(os.path.join(FOLDER_PATH_OUT, tile_name + '_NDVI.tif'))

               
    tiles['path_RGB']=rgb_pathes
    tiles['path_NDVI']=ndvi_pathes

    return tiles