# This scripts aims to run DFT simulations on several LAS files from the same
# directory.

############################### INPUTS #########################################
#   DIR_IN : input directory with LAS files
#   DIR_OUT : directory for output files
#   OVERWRITE :

WORKING_DIR='C:\Users\cmarmy\Documents\STDL\Beeches\delivery\proj-hetres\data\';
DIR_IN =strcat(WORKING_DIR,  '01_initial\lidar_point_cloud\original\');
DIR_OUT = strcat(WORKING_DIR, '02_intermediate\lidar_point_cloud\original\dft_outputs\');

OVERWRITE=1;
################################################################################


fileList = dir(strcat(DIR_IN,'*las'));
number_tiles = size(fileList)(1);

### height second radius
## searchRadius1 = @(h) (3.09632 + 0.00895 * h^2)/2;  % deciduous forest
## searchRadius2 = @(h) (1.7425 * h^0.5566)/2 ;  % mixed forest (Chen et al., 2006)
searchRadius3 = @(h) (1.2 + 0.16 * h)/2 ;  % mixed forest (Pitkanen et al., 2004)

fprintf('Processing tiles...');
for k=1:number_tiles
  %% Step 1 - Reading the LAS file
  filename=strcat(DIR_IN, fileList(k).name);
  pc = LASread(filename);

  minTreeHeight_min = 10;
  [PathIn FileNameOut] = fileparts(filename);
  filename_out=strcat(DIR_OUT, FileNameOut, '_mTH_', strrep(num2str(minTreeHeight_min), '.', 'p'), '_seg.las');
  fprintf(filename_out);
  if OVERWRITE!=0 || !isfile(filename_out)
    funPeaks(pc, minTreeHeight_min, 10, 8, 0.1, 0.5, 'hMaxima', searchRadius3, filename, DIR_OUT);
  else
    fprintf(strcat('The file ', filename_out, ' already exists.'));
    fprintf('Skipping this file.');
  endif

end

fprintf(strcat('Done. Files saved in ', DIR_OUT));
