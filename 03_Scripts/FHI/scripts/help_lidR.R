library(lidR)
LASfile <- system.file("extdata", "Topography.laz", package="lidR") #test data with package lidR

## READ ##

# File #
las <- readLAS("C:/Users/cmarmy/Documents/STDL/Beeches/DFT/data/input/ID_0.las")
las <- readLAS(LASfile, select = "xyzc") #to load only some fields 
plot(las, size = 3, bg = "white")

nz <- nlas@data[["Z"]]
nz_allrows <- nlas@data[(Z>0&Z<2)]
ctg <- filter_poi(ctg, Classification >= 2 & Classification <=5 )
nlas@data$Z

nReturnNumber <- nlas@data[["ReturnNumber"]]

# Catalog "Wall-to-wall" #
ctg <- readLAScatalog("C:/Users/cmarmy/Documents/STDL/Beeches/DFT/data/input/")
plot(ctg, map = TRUE) # display tiles bounding box


## PROCESS ##

# Process individual file #
thr <- c(0,2,5,10,15)
edg <- c(0, 1.5)
chm <- rasterize_canopy(las, 1, pitfree(thr, edg))

# Process a catalog #
chm <- rasterize_canopy(ctg, 2, p2r())
col <- random.colors(50)
plot(chm, col = col)


## FILTER ##¨
gnd <- filter_ground(las) # filter groundpoint 
plot(gnd, size = 3, bg = "white", color = "Classification")


## ------------------SEGMENTATION-------------------------------------------- ##
las <- segment_trees(las, li2012())
col <- random.colors(200)
plot(las, color = "treeID", colorPalette = col)


library(lidR)


# The segmentation to be seamless need to be run on the all region at a time... 
# Which may be quite large. 
dir_las <- 'C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/tmp/'
ctg <- readLAScatalog(dir_las, select = "xyzcrn")

opt_output_files(ctg) <- paste0(tempdir(), "/{*}_dtm")
dtm <- rasterize_terrain(ctg, 1, tin()) 

opt_output_files(ctg) <-  paste0(tempdir(), "/{*}_norm")
ctg_norm <- normalize_height(ctg, dtm)

opt_output_files(ctg_norm) <- paste0(tempdir(), "/chm_{*}")
chm <- rasterize_canopy(ctg_norm, 1, p2r(0.15))

opt_output_files(ctg_norm) <- ""
ttops <- locate_trees(ctg_norm, lmf(4), uniqueness = "bitmerge") #déjà tree ID. 

opt_output_files(ctg_norm) <- paste0(tempdir(), "/{*}_segmented")
algo <- dalponte2016(chm, ttops)
ctg_segmented <- segment_trees(ctg_norm, algo)

opt_output_files(ctg_segmented) <- ""
#lasplot <- clip_circle(ctg_segmented, 338500, 5238600, 40)
pol = crown_metrics(ctg_segmented, NULL, geom = "convex")

plot(sf::st_geometry(pol), col = pastel.colors(250), axes = T)
plot(ctg, add = T)



# Mix option

norm_chunk <- function(chunk)
{
  ### Load LAS file ###
  las <- readLAS(chunk)
  if (is.empty(las)) return(NULL)
  las_f = filter_poi(las, Classification >= 2 & Classification <=5 )
  
  ### DTM, CHM, AGL ###
  dtm <- rasterize_terrain(las_f, 1, tin())
  ctg_norm <- normalize_height(las_f, dtm)
  chm <- rasterize_canopy(ctg_norm, 1, p2r(0.15))
}

ctg <- readLAScatalog(dir_las, select = "xyzcrn")
opt_output_files(ctg) <- paste0('C:/Users/cmarmy/Documents/STDL/Beeches/', "/{*}")
options <- list(automerge = TRUE)
ctg@output_options$drivers$Raster$param$overwrite <- TRUE
ctg@output_options$drivers$Spatial$param$overwrite <- FALSE
output <- catalog_apply(ctg, norm_chunk,.options=options) #SHP

opt_output_files(ctg_norm) <- ""
ttops <- locate_trees(ctg_norm, lmf(4), uniqueness = "bitmerge")

opt_output_files(ctg_norm) <- paste0(tempdir(), "/{*}_segmented")
algo <- dalponte2016(chm, ttops)
ctg_segmented <- segment_trees(ctg_norm, algo)

opt_output_files(ctg_segmented) <- ""
#lasplot <- clip_circle(ctg_segmented, 338500, 5238600, 40)
pol = crown_metrics(ctg_segmented, NULL, geom = "convex")

plot(sf::st_geometry(pol), col = pastel.colors(250), axes = T)
plot(ctg, add = T)




# When processing this way, SHP are generated for each chunk.

norm_chunk <- function(chunk)
{
  ### Load LAS file ###
  las <- readLAS(chunk)
  if (is.empty(las)) return(NULL)
  las_f = filter_poi(las, Classification >= 2 & Classification <=5 )
  
  ### DTM, CHM, AGL ###
  dtm <- rasterize_terrain(las_f, 1, tin())
  ctg_norm <- normalize_height(las_f, dtm)
  chm <- rasterize_canopy(ctg_norm, 1, p2r(0.15))
  ttops <- locate_trees(ctg_norm, lmf(4), uniqueness = "bitmerge")
  algo <- dalponte2016(chm, ttops)
  ctg_segmented <- segment_trees(ctg_norm, algo)
  
  pol = crown_metrics(ctg_segmented, NULL, geom = "convex")
  plot(sf::st_geometry(pol), col = pastel.colors(250), axes = T)
  plot(ctg, add = T)
  return(ctg_segmented)
}

ctg <- readLAScatalog(dir_las, select = "xyzcrn")
opt_output_files(ctg) <- paste0('C:/Users/cmarmy/Documents/STDL/Beeches/', "/{*}")
options <- list(automerge = TRUE)
ctg@output_options$drivers$Raster$param$overwrite <- TRUE
ctg@output_options$drivers$Spatial$param$overwrite <- FALSE
output <- catalog_apply(ctg, norm_chunk,.options=options) #SHP


#-------------------------------------------------------------------------------


## ANALYSE PIXEL TO RASTER 
hmean <- pixel_metrics(las, ~mean(Z), 10) # calculate mean at 10 m

# more elaborate analyse 
f <- function(x) { # user-defined fucntion
  list(mean = mean(x), sd = sd(x)) #add any metrics or combination of metrics https://github.com/r-lidar/lidR/wiki/stdmetrics
}

metrics <- pixel_metrics(las, ~f(Z), 10) # calculate grid metrics
plot(metrics, col = height.colors(50))


## SPATRASTER ##
myCRS <- crs(chm, describe=TRUE, proj=TRUE)
mySpat <- rast(nrows=300, ncols=300, nlyrs=1, xmin=myExt[1],xmax=myExt[2],ymin=myExt[3],ymax=myExt[4])
values(mySpat)=0
myExt <- ext(mySpat)

## Specific to project 
# # Chose only the polygones corresponding to the GT. @ RF.R
# GT_params<-st_join(seg_params, GT, left=FALSE, right=FALSE)
# st_write(GT_params,"C:/Users/cmarmy/Documents/STDL/Beeches/proj-hetres/03_Scripts/FHI/GT_segFun_h.shp", driver = "ESRI Shapefile", append=TRUE)