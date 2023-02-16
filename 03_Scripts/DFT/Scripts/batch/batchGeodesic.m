% addpath(genpath('D:\Documents\Flann\STDL\DigitalForestry\DFT_mParkan'))
% DIGITAL FORESTRY TOOLBOX - TUTORIAL 5
% This tool attempts to batch process the steps from Tutorial 5 over the same dataset
% multiple times, by modifiying the values of a given parameter from the geodesicVote function
% over a given range.
% Both the parameter to modify and the range can be given as input by the user.
%
% GEODESIC_VOTE_DEMO - example of Individual Tree Crown (ITC) segmentation using the algorith described in [1].
%
% [1] Parkan, Matthew and Tuia, Devis, "Individual Tree Segmentation in Deciduous Forests Using Geodesic Voting",
% in Geoscience and Remote Sensing Symposium, 2015. IGARSS’15. 2015 IEEE International, 2015.
%
% The following steps are illustrated:
% 1. Importing a point cloud from a LAS file
% 2. Segmentation (i.e. labelling individual tree crowns)
% 3. Ploting results
%
% Other m-files required: LASread.m, subsample.m, clusterColor.m, geodesicVote.m
% Subfunctions: none
% MAT-files required: none
% Compatibility: tested on Matlab R2021a
%
% Author: Matthew Parkan (matthew.parkan@gmail.com)
% Website:
% Last revision: November 24, 2021
% Acknowledgments: This work was supported by the Swiss Forestry and Wood Research Fund (WHFF, OFEV), project 2013.18
% Licence: GNU General Public Licence (GPL), see https://www.gnu.org/licenses/gpl.html for details

clc
clear
close all

OCTAVE_FLAG = (exist('OCTAVE_VERSION', 'builtin') ~= 0); % determine if system is Matlab or GNU Octave

if OCTAVE_FLAG
    
    pkg load statistics
    pkg load image

end


% We need to get as input both the parameter to explore
% and the range of values it explores.
choiceList = {'cellSize', 'bandWidth', 'verticalStep', 'searchRadius', 'minLength'};

% Let the user input the default parameter values (defParVal).
defParVal = inputdlg(choiceList, ...
  'Enter parameter default values...', ...
  [1 1 1 1 1], ...
  {'0.9', '0.7', '0.15', '2.8', '1.4'});
% Convert cell array answer to matrix of numerical values, thanks to cellfun
defParVal = cellfun(@(x) str2num(x), defParVal);

% Assign all default parameter values.
cellSizeDefault = defParVal(1);
bandWidthDefault = defParVal(2);
verticalStepDefault = defParVal(3);
searchRadiusDefault = defParVal(4);
minLengthDefault = defParVal(5);


% listdlg lets the user select a parameter from a dropdown menu.
% It returns the index of the chosen item.
chosenIndex = listdlg ('ListString', choiceList, ...
  'SelectionMode', 'Single', ...
  'Name', 'Choose parameter to explore');
  
% We can then obtain the chosen parameter (named par) by looking up what item corresponds
% to the index returned by listdlg. Convert the cell array to a string with char().
par = char(choiceList(chosenIndex));


% Let the user input the range to be explored by the chosen parameter
parRange = inputdlg({'Minimum range value', 'Maximum range value', 'Step'},...
 'Enter parameter range properties...');
% Convert cell array answer to matrix of numerical values, thanks to cellfun
parRange = cellfun(@(x) str2num(x), parRange);

% 1 is minvalue, 2 is maxvalue, 3 is step.
minVal = parRange(1);
maxVal = parRange(2);
stepVal = parRange(3);


% Select input LAS point cloud path.
[LASFileIn, LASFolderIn] = uigetfile('.las', 'Select LAS-format point cloud...');
% Full path already has .las extension.
LASPathIn = strcat(LASFolderIn, LASFileIn);

% Select output SHP path.
[FileNameOut, FolderOut] = uiputfile([], 'Select output folder and output SHP file name...');
% Full path does NOT have full path extension. 
% Used to create multiple files with same name and different extension.
PathOut = strcat(FolderOut, FileNameOut);