# funPeaks(minTreeHeight_min, minTreeHeight_max, minTreeHeight_step, cellSize, method_peaks, myFun, LASPathIn, PathOut)
myFun1 = @(h) (3.09632 + 0.00895 * h^2)/2
myFun2 = @(h) (1.7425 * h^0.5566)/2 ;
myFun3 = @(h) (1.2 + 0.16 * h)/2 ;

list_tiles =[ 'ID_94'; ...
              'ID_91'; ...
              'ID_85'; ...
              'ID_84'; ...
              'ID_58'; ...
              'ID_54'; ...
              'ID_53'; ...
              'ID_45'; ...
              'ID_36'; ...
              'ID_27'; ...
              'ID_18'; ...
              'dissID_46_47'; ...
              'dissID_28_29_73_74'; ...
              'dissID_9_12'; ...
              'dissID_6_7_8_87_88';...
              'dissID_0_1_5_6'; ...
              'dissID_93_13'; ...
              'dissID_79_83'; ...
              'dissID_55_56_57'];

length_list = length(list_tiles);


for k=1:length_list
  %% Step 1 - Reading the LAS file
  pc = LASread(strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:),'.las'));

  funPeaks(pc, 2, 10, 8, 0.5, 'default', myFun3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2_GTseg\')
  %funPeaks(pc, 2, 10, 8, 0.5, 'hMaxima', myFun3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\')
  #funPeaks(pc, 2, 10, 8, 0.5, 'hMaxima', 0.3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2_GTseg\')
 end


##  funPeaks(pc, 2, 10, 4, 0.5, 'default', myFun1, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHfun1\')
##  funPeaks(pc, 2, 10, 4, 0.5, 'default', myFun2, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHfun2\')
##  funPeaks(pc, 2, 10, 4, 0.5, 'default', myFun3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHfun3\')
##  funPeaks(pc, 2, 10, 4, 0.5, 'hMaxima', myFun1, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHdH0p1\')
##  funPeaks(pc, 2, 10, 4, 0.5, 'hMaxima', myFun2, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHdH0p3\')
##  funPeaks(pc, 2, 10, 4, 0.5, 'hMaxima', myFun3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHdH0p5\')
##  funPeaks(pc, 2, 10, 4, 1.0, 'default', myFun1, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHfun1\')
##  funPeaks(pc, 2, 10, 4, 1.0, 'default', myFun2, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHfun2\')
##  funPeaks(pc, 2, 10, 4, 1.0, 'default', myFun3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHfun3\')
##  funPeaks(pc, 2, 10, 4, 1.0, 'hMaxima', myFun1, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHdH0p1\')
##  funPeaks(pc, 2, 10, 4, 1.0, 'hMaxima', myFun2, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHdH0p3\')
##  funPeaks(pc, 2, 10, 4, 1.0, 'hMaxima', myFun3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHdH0p5\')
##  funPeaks(pc, 2, 10, 4, 1.5, 'default', myFun1, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHfun1\')
##  funPeaks(pc, 2, 10, 4, 1.5, 'default', myFun2, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHfun2\')
##  funPeaks(pc, 2, 10, 4, 1.5, 'default', myFun3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHfun3\')
##  funPeaks(pc, 2, 10, 4, 1.5, 'hMaxima', myFun1, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHdH0p1\')
##  funPeaks(pc, 2, 10, 4, 1.5, 'hMaxima', myFun2, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHdH0p3\')
##  funPeaks(pc, 2, 10, 4, 1.5, 'hMaxima', myFun3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHdH0p5\')
##  funPeaks(pc, 2, 10, 4, 2.0, 'default', myFun1, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHfun1\')
##  funPeaks(pc, 2, 10, 4, 2.0, 'default', myFun2, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHfun2\')
##  funPeaks(pc, 2, 10, 4, 2.0, 'default', myFun3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHfun3\')
##  funPeaks(pc, 2, 10, 4, 2.0, 'hMaxima', myFun1, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHdH0p1\')
##  funPeaks(pc, 2, 10, 4, 2.0, 'hMaxima', myFun2, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHdH0p3\')
##  funPeaks(pc, 2, 10, 4, 2.0, 'hMaxima', myFun3, strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\', list_tiles(k,:)), 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHdH0p5\')

##funPeaks(2, 10, 4, 0.5, 'default', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHfun1\')
##funPeaks(2, 10, 4, 0.5, 'default', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHfun2\')
##funPeaks(2, 10, 4, 0.5, 'default', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHfun3\')
##funPeaks(2, 10, 4, 0.5, 'hMaxima', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHdH0p1\')
##funPeaks(2, 10, 4, 0.5, 'hMaxima', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHdH0p3\')
##funPeaks(2, 10, 4, 0.5, 'hMaxima', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHdH0p5\')
##funPeaks(2, 10, 4, 1.0, 'default', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHfun1\')
##funPeaks(2, 10, 4, 1.0, 'default', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHfun2\')
##funPeaks(2, 10, 4, 1.0, 'default', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHfun3\')
##funPeaks(2, 10, 4, 1.0, 'hMaxima', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHdH0p1\')
##funPeaks(2, 10, 4, 1.0, 'hMaxima', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHdH0p3\')
##funPeaks(2, 10, 4, 1.0, 'hMaxima', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHdH0p5\')
##funPeaks(2, 10, 4, 1.5, 'default', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHfun1\')
##funPeaks(2, 10, 4, 1.5, 'default', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHfun2\')
##funPeaks(2, 10, 4, 1.5, 'default', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHfun3\')
##funPeaks(2, 10, 4, 1.5, 'hMaxima', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHdH0p1\')
##funPeaks(2, 10, 4, 1.5, 'hMaxima', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHdH0p3\')
##funPeaks(2, 10, 4, 1.5, 'hMaxima', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHdH0p5\')
##funPeaks(2, 10, 4, 2.0, 'default', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHfun1\')
##funPeaks(2, 10, 4, 2.0, 'default', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHfun2\')
##funPeaks(2, 10, 4, 2.0, 'default', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHfun3\')
##funPeaks(2, 10, 4, 2.0, 'hMaxima', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHdH0p1\')
##funPeaks(2, 10, 4, 2.0, 'hMaxima', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHdH0p3\')
##funPeaks(2, 10, 4, 2.0, 'hMaxima', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\sampleMIE.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHdH0p5\')
##
##funPeaks(2, 10, 4, 0.5, 'default', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHfun1\')
##funPeaks(2, 10, 4, 0.5, 'default', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHfun2\')
##funPeaks(2, 10, 4, 0.5, 'default', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHfun3\')
##funPeaks(2, 10, 4, 0.5, 'hMaxima', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHdH0p1\')
##funPeaks(2, 10, 4, 0.5, 'hMaxima', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHdH0p3\')
##funPeaks(2, 10, 4, 0.5, 'hMaxima', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\0p5mTHdH0p5\')
##funPeaks(2, 10, 4, 1.0, 'default', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHfun1\')
##funPeaks(2, 10, 4, 1.0, 'default', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHfun2\')
##funPeaks(2, 10, 4, 1.0, 'default', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHfun3\')
##funPeaks(2, 10, 4, 1.0, 'hMaxima', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHdH0p1\')
##funPeaks(2, 10, 4, 1.0, 'hMaxima', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHdH0p3\')
##funPeaks(2, 10, 4, 1.0, 'hMaxima', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p0mTHdH0p5\')
##funPeaks(2, 10, 4, 1.5, 'default', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHfun1\')
##funPeaks(2, 10, 4, 1.5, 'default', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHfun2\')
##funPeaks(2, 10, 4, 1.5, 'default', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHfun3\')
##funPeaks(2, 10, 4, 1.5, 'hMaxima', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHdH0p1\')
##funPeaks(2, 10, 4, 1.5, 'hMaxima', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHdH0p3\')
##funPeaks(2, 10, 4, 1.5, 'hMaxima', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\1p5mTHdH0p5\')
##funPeaks(2, 10, 4, 2.0, 'default', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHfun1\')
##funPeaks(2, 10, 4, 2.0, 'default', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHfun2\')
##funPeaks(2, 10, 4, 2.0, 'default', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHfun3\')
##funPeaks(2, 10, 4, 2.0, 'hMaxima', myFun1, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHdH0p1\')
##funPeaks(2, 10, 4, 2.0, 'hMaxima', myFun2, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHdH0p3\')
##funPeaks(2, 10, 4, 2.0, 'hMaxima', myFun3, 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\input\dissID_9_12.las', 'C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\2p0mTHdH0p5\')
