#funStems(cellSize, bandWidth, verticalStep, searchRadius, minLength, par, Param_min, Param_max, Param_step, LASPathIn, PathOut)

list_tiles =[ #'dissID_46_47'; ...
              #'dissID_28_29_73_74'; ...
              #'dissID_9_12'; ...
              #'dissID_6_7_8_87_88';...
              #'ID_94'; ...
              #'ID_91'; ...
              #'ID_85'; ...
              #'ID_84'; ...
              #'ID_58'; ...
              #'ID_54'; ...
              #'ID_53'; ...
              #'ID_45'; ...
              #'ID_36'; ...
              #'ID_27'; ...
              #'ID_18'; ...
              #'dissID_93_13'; ...
              'dissID_79_83'; ...
              'dissID_0_1_5_6'; ...
              'dissID_55_56_57'];

length_list = length(list_tiles);

for k=1:length_list
  funStems(0.4, 1.5, 0.25, 2, 5, 'cellSize', 0.2, 0.6, 0.20, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRcellSize\')
  funStems(0.4, 1.5, 0.25, 2, 5, 'bandWidth', 1.0, 2.0, 0.50,strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRBandwidth\')
  funStems(0.4, 1.5, 0.25, 2, 5, 'verticalStep', 0.1, 0.4, 0.15,strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRverticalStep\')
  funStems(0.4, 1.5, 0.25, 2, 5, 'searchRadius', 1.5, 2.5, 0.50,strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRsearchRadius\')
  funStems(0.4, 1.5, 0.25, 2, 5, 'minLength', 3.0, 7.0, 2.00,strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRminLength\')
  funStems(0.4, 1.5, 0.25, 2, 5, 'cellSize', 0.2, 0.6, 0.20,strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARcellSize\')
  funStems(0.4, 1.5, 0.25, 2, 5, 'bandWidth', 1.0, 2.0, 0.50,strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARBandwidth\')
  funStems(0.4, 1.5, 0.25, 2, 5, 'verticalStep', 0.1, 0.4, 0.15,strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARverticalStep\')
  funStems(0.4, 1.5, 0.25, 2, 5, 'searchRadius', 1.5, 2.5, 0.50,strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARsearchRadius\')
  funStems(0.4, 1.5, 0.25, 2, 5, 'minLength', 3.0, 7.0, 2.00,strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARminLength\')
end


## "par" TO ADD
##  funStems(0.4, 1.5, 0.25, 2, 5, 0.2, 0.6, 0.20, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRcellSize\')
##  funStems(0.4, 1.5, 0.25, 2, 5, 1.0, 2.0, 0.50, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRBandwidth\')
##  funStems(0.4, 1.5, 0.25, 2, 5, 0.1, 0.4, 0.15, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRverticalStep\')
##  funStems(0.4, 1.5, 0.25, 2, 5, 1.5, 2.5, 0.50, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRsearchRadius\')
##  funStems(0.4, 1.5, 0.25, 2, 5, 3.0, 7.0, 2.00, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRminLength\')
##  funStems(0.4, 1.5, 0.25, 2, 5, 0.2, 0.6, 0.20, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARcellSize\')
##  funStems(0.4, 1.5, 0.25, 2, 5, 1.0, 2.0, 0.50, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARBandwidth\')
##  funStems(0.4, 1.5, 0.25, 2, 5, 0.1, 0.4, 0.15, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARverticalStep\')
##  funStems(0.4, 1.5, 0.25, 2, 5, 1.5, 2.5, 0.50, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARsearchRadius\')
##  funStems(0.4, 1.5, 0.25, 2, 5, 3.0, 7.0, 2.00, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:) ,'.las'), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARminLength\')

##funStems(0.4, 1.5, 0.25, 2, 5, 'cellSize', 0.2, 0.6, 0.2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRcellSize\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'bandWidth', 1, 2, 0.5, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRBandwidth\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'verticalStep', 0.1, 0.4, 0.15, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRverticalStep\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'searchRadius', 1.5, 2.5, 0.5, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRsearchRadius\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'minLength', 3.0, 7.0, 2.0, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRminLength\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'cellSize', 0.2, 0.6, 0.2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARcellSize\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'bandWidth', 1, 2, 0.5, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARBandwidth\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'verticalStep', 0.1, 0.4, 0.15, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARverticalStep\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'searchRadius', 1.5, 2.5, 0.5, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARsearchRadius\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'minLength', 3.0, 7.0, 2.0, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARminLength\')

##funStems(0.4, 1.5, 0.25, 2, 5, 'cellSize', 0.2, 0.6, 0.2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRcellSize\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'bandWidth', 1, 2, 0.5, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRBandwidth\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'verticalStep', 0.1, 0.4, 0.15, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRverticalStep\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'searchRadius', 1.5, 2.5, 0.5, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRsearchRadius\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'minLength', 3.0, 7.0, 2.0, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\LRminLength\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'cellSize', 0.2, 0.6, 0.2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARcellSize\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'bandWidth', 1, 2, 0.5, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARBandwidth\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'verticalStep', 0.1, 0.4, 0.15, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARverticalStep\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'searchRadius', 1.5, 2.5, 0.5, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARsearchRadius\')
##funStems(0.4, 1.5, 0.25, 2, 5, 'minLength', 3.0, 7.0, 2.0, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\ARminLength\')

