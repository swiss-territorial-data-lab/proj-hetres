% DIGITAL FORESTRY TOOLBOX - TUTORIAL 3
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

if OCTAVE_FLAG
    
    pkg load statistics
    pkg load image

end
    
%% Step 1 - Read the LAS file

% IMPORTANT: adjust the path to the input LAS file
pc = LASread('ge_2017_a.las');


%% Step 2 - Normalize the point cloud elevation

% compute the terrain model
cellSize = 0.5;
[models, refmat] = elevationModels([pc.record.x, pc.record.y, pc.record.z], ...
    pc.record.classification, ...
    'classTerrain', [2], ...
    'classSurface', [4,5], ...
    'cellSize', cellSize, ...
    'closing', 5, ...
    'interpolation', 'idw', ...
    'searchRadius', inf, ...
    'weightFunction', @(d) d^-3, ...
    'smoothingFilter', fspecial('gaussian', [2, 2], 0.8), ...
    'outputModels', {'terrain'}, ...
    'fig', false, ...
    'verbose', true);

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

[label, xyh_stem] = treeStems(xyh, ...
    idxl_filter, ...
    'cellSize', 0.4, ...
    'bandWidth', 1.5, ...
    'verticalStep', 0.25, ...
    'searchRadius', 2, ...
    'minLength', 5, ...
    'verbose', true, ...
    'fig', true);


%% Step 5 - Export stem attributes to a CSV file

% IMPORTANT: adjust the path to the output CSV file
fid = fopen('ge_2017_a_stems.csv', 'w+'); % open file
fprintf(fid, 'X, Y, H\n'); % write header line
fprintf(fid, '%.2f, %.2f, %.2f\n', xyh_stem'); % write records
fclose(fid); % close file


%% Step 6 - Export stem attributes to an ESRI shapefile

S = struct('Geometry', repmat({'Point'}, size(xyh_stem,1),1), ...
      'X', num2cell(xyh_stem(:,1)), ...
      'Y', num2cell(xyh_stem(:,2)), ...
      'BoundingBox', [], ...
      'H', num2cell(xyh_stem(:,3)));

% write non-scalar structure to SHP file
% IMPORTANT: the shapewrite() function included here is currently 
% not compatible with Matlab. Matlab users should use the shapewrite()
% function from the offical Matlab mapping toolbox instead.
shapewrite(S, 'ge_2017_a_stems.shp'); % IMPORTANT: adjust the path to the output SHP file
