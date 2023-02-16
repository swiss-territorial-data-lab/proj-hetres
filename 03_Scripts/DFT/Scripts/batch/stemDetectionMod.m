% addpath(genpath('D:\Documents\Flann\STDL\DigitalForestry\DFT_mParkan'))
% DIGITAL FORESTRY TOOLBOX - TUTORIAL 3

%  CM: This is the not batched script for stem detection


%
% Other m-files required: LASread.m, elevationModels.m, treeStems.m
% Subfunctions: none
% MAT-files required: none
% Compatibility: tested on Matlab R2019b, GNU Octave 5.2.0 (configured for "x86_64-w64-mingw32")
%
% See also:
%
% This code is part of the Matlab Digital Forestry Toolbox
%
% Author: Matthew Parkan, EPFL - GIS Research Laboratory
% Website: http://mparkan.github.io/Digital-Forestry-Toolbox/
% Last revision: February 24, 2020
% Acknowledgments: This work was supported by the Swiss Forestry and Wood Research Fund (WHFF, OFEV), project 2013.18
% Licence: GNU General Public Licence (GPL), see https://www.gnu.org/licenses/gpl.html for details

clc
clear
close all

OCTAVE_FLAG = (exist('OCTAVE_VERSION', 'builtin') ~= 0); % determine if system is Matlab or GNU Octave
only_SHP_points_output_FLAG = true

if OCTAVE_FLAG

    pkg load statistics
    pkg load image

end


% We need to get as input both the parameter to explore
% and the range of values it explores.
choiceList = {'cellSize', 'bandWidth', 'verticalStep', 'searchRadius', 'minLength'};

% Let the user input the default parameter values.
defParVal = inputdlg(choiceList, ...
  'Enter parameter values...', ...
  [1 1 1 1 1], ...
  {'0.9', '0.7', '0.15', '4', '4'});
% Convert cell array answer to matrix of numerical values, thanks to cellfun
defParVal = cellfun(@(x) str2num(x), defParVal);

% Assign all default parameter values.
cellSizeDefault = defParVal(1);
bandWidthDefault = defParVal(2);
verticalStepDefault = defParVal(3);
searchRadiusDefault = defParVal(4);
minLengthDefault = defParVal(5);


% Select input LAS point cloud path.
[LASFileIn, LASFolderIn] = uigetfile('.las', 'Select LAS-format point cloud...');
% Full path already has .las extension.
LASPathIn = strcat(LASFolderIn, LASFileIn);

% Select output SHP path.
[FileNameOut, FolderOut] = uiputfile([], 'Select output folder and output SHP file name...');
% Full path does NOT have full path extension.
% Used to create multiple files with same name and different extension.
PathOut = strcat(FolderOut, FileNameOut);


%% Step 1 - Read the LAS file

% IMPORTANT: adjust the path to the input LAS file
pc = LASread(LASPathIn);


%% Step 2 - Normalize the point cloud elevation

c1 = fix(clock);
fprintf('Terrain Model comuptation started at %d:%d:%d\n', c1(4), c1(5), c1(6));

% compute the terrain model
% try for cellSize influence on computation time
% cellSize default value is 0.5
% With a 0.8 cellsize value, computation time is approx. 7 mins in Octave, 1 min in matlab.
% Untested for 0.5 cellsize value. If 3D, could take 30mins total in Octave.
cellSize = 0.8;
[models, refmat] = elevationModels([pc.record.x, pc.record.y, pc.record.z], ...
    pc.record.classification, ...
    'classTerrain', [2], ...
    'classSurface', [4,5], ...
    'cellSize', cellSize, ...
    'closing', 5, ...
    'interpolation', 'idw', ...
    'searchRadius', 10, ... %change to 10 to make it faster, initial value inf
    'weightFunction', @(d) d^-3, ...
    'smoothingFilter', fspecial('gaussian', [2, 2], 0.8), ...
    'outputModels', {'terrain'}, ...
    'fig', false, ...
    'verbose', true);

c2 = fix(clock);
fprintf('Terrain Model comuptation ended at %d:%d:%d\n', c2(4), c2(5), c2(6));

if c2(5) < c1(5)
  mins_elapsed = c2(5) - c1(5) + 60;
else
  mins_elapsed = c2(5) - c1(5);
end
fprintf('Approx. time elapsed during Terrain Model comuptation : %d minutes.\n', mins_elapsed);

[nrows, ncols] = size(models.terrain.values);

% subtract the terrain elevation from the point cloud elevation
P = round([pc.record.x - refmat(3,1), pc.record.y - refmat(3,2)] / refmat(1:2,:));
ind = sub2ind([nrows, ncols], P(:,1), P(:,2));
xyh = [pc.record.x, pc.record.y, pc.record.z - models.terrain.values(ind)];


%% Step 3 - Filter points by classification and return index

idxl_last = pc.record.return_number == pc.record.number_of_returns; % derniers echos
idxl_veg = ismember(pc.record.classification, [4, 5]); % classe v�g�tation haute
idxl_filter = idxl_veg & idxl_last; % combiner les filtres

%% Step 4 - Detect stems
% Here are many parameters we can experiment with.

[label, xyh_stem] = treeStems(xyh, ...
    idxl_filter, ...
    'cellSize', cellSizeDefault, ...
    'bandWidth', bandWidthDefault, ...
    'verticalStep', verticalStepDefault, ...
    'searchRadius', searchRadiusDefault, ...
    'minLength', minLengthDefault, ...
    'verbose', true, ...
    'fig', true);


%% Step 5 - Export stem attributes to a CSV file

if ~only_SHP_points_output_FLAG

  fid = fopen(strcat(PathOut, '_stems.csv'), 'w+'); % open file
  fprintf(fid, 'X, Y, H\n'); % write header line
  fprintf(fid, '%.2f, %.2f, %.2f\n', xyh_stem'); % write records
  fclose(fid); % close file

end

%% Step 6 - Export stem attributes to an ESRI shapefile

S = struct('Geometry', repmat({'Point'}, size(xyh_stem,1),1), ...
      'X', num2cell(xyh_stem(:,1)), ...
      'Y', num2cell(xyh_stem(:,2)), ...
      'BoundingBox', [], ...
      'H', num2cell(xyh_stem(:,3)));

% write non-scalar structure to SHP file
% IMPORTANT: the shapewrite() function included here is currently
% not compatible with Matlab. Matlab users should use the shapewrite()
% function from the official Matlab mapping toolbox instead.
if OCTAVE_FLAG
  shapewriteOctave(S, strcat(PathOut, '_stems.shp'));
else
  shapewrite(S, strcat(PathOut, '_stems.shp'));
end


fprintf('PROGRAM ENDED SUCCESSFULLY\n');
