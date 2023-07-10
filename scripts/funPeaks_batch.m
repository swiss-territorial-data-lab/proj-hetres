# This scripts aims to run DFT simulations on several LAS files from the same
# directory.

############################### INPUTS #########################################
#   DIR_IN : input directory with LAS files
#   DIR_OUT : directory for output files

DIR_IN = 'C:\Users\cmarmy\Documents\STDL\Beeches\delivery\data\01_initial\lidar_point_cloud\original\'
DIR_OUT = 'C:\Users\cmarmy\Documents\STDL\Beeches\delivery\data\02_intermediate\lidar_point_cloud\original\dft_outputs\'

################################################################################


fileList = dir(strcat(DIR_IN,'*las'));
number_tiles = size(fileList)(1);

### height second radius
## myFun1 = @(h) (3.09632 + 0.00895 * h^2)/2
## myFun2 = @(h) (1.7425 * h^0.5566)/2 ;
myFun3 = @(h) (1.2 + 0.16 * h)/2 ;

for k=1:number_tiles
  %% Step 1 - Reading the LAS file
  pc = LASread(strcat(DIR_IN, fileList(k).name));

  funPeaks(pc, 10, 10, 8, 0.1, 0.5, 'hMaxima', myFun3, strcat(DIR_IN, fileList(k).name), strcat(DIR_OUT))
end


