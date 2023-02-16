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


## SEGMENTATION ##
las <- segment_trees(las, li2012())
col <- random.colors(200)
plot(las, color = "treeID", colorPalette = col)


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