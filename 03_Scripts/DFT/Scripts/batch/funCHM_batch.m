# CHM generation
  clc
  clear
  close all

  OCTAVE_FLAG = (exist('OCTAVE_VERSION', 'builtin') ~= 0); % determine if system is Matlab or GNU Octave

  if OCTAVE_FLAG

      pkg load statistics
      pkg load image
      more off

  end


main_dir = 'C:\Users\cmarmy\Desktop\';
files = dir(fullfile(main_dir,'**','*.las'));

length_list = length(files);


for k=1:length_list
  %% Step 1 - Reading the LAS file
  pc = LASread(strcat('C:\Users\cmarmy\Documents\STDL\Beeches\02_data\Helimap\03B_LiDAR_With_Intensity\02_PROCESSED\', files(k).name));

  funCHM(pc,strcat('C:\Users\cmarmy\Documents\STDL\Beeches\DFT\data\output\CHM\',files(k).name))
 end
