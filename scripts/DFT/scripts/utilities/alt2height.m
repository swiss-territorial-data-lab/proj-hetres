function xyh = alt2height(xyz, classification, varargin)
% ALT2HEIGHT - converts 3D point cloud altitude to height above terrain.
% XYH = ALT2HEIGHT(XYZ, CLASSIFICATION, ...) computes a 3D terrain model using the interpolation specified
% with METHOD and subtracts terrain altitude from the points.
% 
% Syntax:  xyh = alt2height(xyz, classification, ...)
% 
% Inputs:
%    xyz - Nx3 numeric matrix, 3D point cloud coordinates [x y z]
%
%    classification - Nx1 integer vector, classification
%
%    classTerrain (optional, default: 2) - integer vector, terrain class numbers
% 
%    method (optional, default: 'linear') - string, any of the interpolation methods supported by
%    griddata ('nearest', 'linear', 'cubic')
%
%    verbose (optional, default: true) - boolean value, verbosiy switch
%
%
% Outputs:
%    xyh - Nx3 numeric matrix, normalized 3D point cloud coordinates [x y h]
% 
% Example:
%
% pc = LASread('..\data\measurements\vector\als\zh_2014_coniferous.las');
%
% xyh = alt2height([pc.record.x, pc.record.y, pc.record.z], ...
%     pc.record.classification, ...
%     'classTerrain', 2, ...
%     'method', 'linear');
% 
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
% Compatibility: tested on Matlab R2017b, GNU Octave 4.2.1 (configured for "x86_64-w64-mingw32")
% 
% See also:
% 
% This code is part of the Matlab Digital Forestry Toolbox
% 
% Author: Matthew Parkan, EPFL - GIS Laboratory (LASIG)
% Website: http://mparkan.github.io/Digital-Forestry-Toolbox/
% Last revision: April 6, 2018
% Acknowledgments: This work was supported by the Swiss Forestry and Wood Research Fund (WHFF, OFEV), project 2013.18
% Licence: GNU General Public Licence (GPL), see https://www.gnu.org/licenses/gpl.html for details


%% check argument validity

arg = inputParser;

addRequired(arg, 'xyz', @(x) (size(x,2) >= 2) && (size(x,2) == 3) && isnumeric(x));
addRequired(arg, 'classification', @(x) (size(x,2) == 1) && isnumeric(x));
addParameter(arg, 'classTerrain', 2, @(x) isnumeric(x));
addParameter(arg, 'method', 'linear', @(x) ismember(x, {'nearest', 'linear', 'natural', 'cubic', 'v4'}));
addParameter(arg, 'verbose', true, @(x) islogical(x) && (numel(x) == 1));

parse(arg, xyz, classification, varargin{:});

OCTAVE_FLAG = (exist('OCTAVE_VERSION', 'builtin') ~= 0); % determine if system is Matlab or GNU Octave

if OCTAVE_FLAG
    
    more off % disable pager
    
end


%% compute terrain model

if arg.Results.verbose
    
    tic
    fprintf('interpolating terrain points...');
    
end

% filter relevant point classes
idxl_ter = ismember(classification, arg.Results.classTerrain);
xyz_ter = xyz(idxl_ter,:);

% interpolate terrain points
z0 = griddata(xyz_ter(:,1), ...
    xyz_ter(:,2), ...
    xyz_ter(:,3), ...
    xyz(:,1), ...
    xyz(:,2), ...
    arg.Results.method);

if arg.Results.verbose
    
    fprintf('done!\n');
    toc
    
end


%% extrapolate missing values

if arg.Results.verbose
    
    tic
    fprintf('extrapolating missing values (nearest neighbour search)...');
    
end

idxl_nan = isnan(z0);

if any(idxl_nan)
    
    z0(idxl_nan) = griddata(xyz_ter(:,1), ...
        xyz_ter(:,2), ...
        xyz_ter(:,3), ...
        xyz(idxl_nan,1), ...
        xyz(idxl_nan,2), ...
        'nearest');
    
end

if arg.Results.verbose
    
    fprintf('done!\n');
    toc
    
end


%% subtract terrain elevation to points

if arg.Results.verbose
    
    fprintf('subtracting terrain elevation to points...');
    
end

h = xyz(:,3) - z0;
h(h < 0) = 0;

xyh = [xyz(:,1:2), h];

if arg.Results.verbose
    
    fprintf('done!\n');
    
end
