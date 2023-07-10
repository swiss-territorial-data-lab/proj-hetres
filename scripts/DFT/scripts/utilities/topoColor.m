function varargout = topoColor(X, label, varargin)
% TOPOCOLOR - assigns distinct colors to adjacent 3D point clusters (topological graph colouring)
% using the largest degree first heuristic described in [1] and [2].
% [COLOR, RGB] = TOPOCOLOR(X, LABEL, ...) assigns a distinct color index (COLOR) and RGB triplet (RGB) to each
% 3D labelled point cluster specified with X and LABEL. Clusters are considered adjacent if their 2D or 3D extents 
% (plus an optional buffer) intersect. The colormaps are based on the values provided in [3] and [4].
%
% [1] Welsh Dominic JA, and B. Powell Martin. "An upper bound for the chromatic number of a graph and its application to timetabling problems." 
% The Computer Journal 10.1 (1967): 85-86.
% [2] Kosowski Adrian and Manuszewski, Krzysztof. "Classical coloring of graphs." Contemporary Mathematics 352 (2004): 1-20.
% [3] Brewer Cynthia and Harrower Marc, "ColorBrewer 2.0 - Color advice for
% cartography", Pennsylvania State University, http://colorbrewer2.org/#type=qualitative&scheme=Paired&n=12
% [4] Jacomy Mathieu, "I want hue - Colors for data scientists", Sciences-Po Medialab, http://tools.medialab.sciences-po.fr/iwanthue/
%
% Syntax:  
%    topoColor(X, label, ...)
%    color = topoColor(X, label, ...)
%    [color, rgb] = topoColor(X, label, ...)
%    [color, rgb, cmap] = topoColor(X, label, ...)
%
% Inputs:
%    X - Nx2 or Nx3 numeric matrix, 2D or 3D point coordinates [x y] or [x y z]
%
%    label - Nx1 integer vector, individual cluster label
%
%    adjacency (optional, default: '3d') - string ('2d' or '3d') -
%    adjacency mode. In 2D mode only the horizontal distance between clusters is used.
%
%    buffer (optional, default: 2) - float, width of the buffer around each cluster. 
%    Points are voxelized to the buffer resolution.
%
%    colormap (optional, default: 'cmap12') - string, 'hsv', 'cmap12', 'cmap25'
%
%    unlabelledColor (optional, default: [0,0,0]) - 3x1 numeric matrix,
%    RGB triplet associated with label 0 (i.e. unlabelled)
%
%    verbose (optional, default: true) - boolean value, verbosiy switch
%
%    fig (optional, default: false) - boolean value, switch to plot figures
%
% Outputs:
%    color - Nx1 integer vector, distinct color index
%
%    rgb - Mx3 numeric matrix, RGB triplets associated with each 3D point,
%    unlabelled points are in black by default [0,0,0]
%
%    cmap - Kx3 numeric matrix, colormap
%
% Example:
%
%    [color, rgb, cmap] = topoColor([x y z], ...
%                label, ...
%                'adjacency', '3d', ...   
%                'buffer', 3, ...
%                'colormap', 'cmap12', ...
%                'unlabelledColor', [0.1, 0.1, 0.1], ...
%                'fig', true, ...
%                'verbose', true);
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
% Author: Matthew Parkan, EPFL - GIS Research Laboratory (LASIG)
% Website: http://mparkan.github.io/Digital-Forestry-Toolbox/
% Last revision: March 23, 2018
% Acknowledgments: This work was supported by the Swiss Forestry and Wood
% Research Fund, WHFF (OFEV) - project 2013.18
% Licence: GNU General Public Licence (GPL), see https://www.gnu.org/licenses/gpl.html for details


%% check argument validity

arg = inputParser;

addRequired(arg, 'X', @(x) (size(x,2) >= 2) && (size(x,2) <= 3) && isnumeric(x));
addRequired(arg, 'label', @(x) (size(x,2) == 1) && isnumeric(x));
addParameter(arg, 'adjacency', '3d', @(x) ismember(x, {'2d', '3d'}));
addParameter(arg, 'buffer', 2, @(x) isnumeric(x) && (numel(x) == 1) && x >= 0);
addParameter(arg, 'colormap', 'cmap12', @(x) ismember(x, {'auto', 'hsv', 'cmap12', 'cmap25'}));
addParameter(arg, 'unlabelledColor', [0,0,0], @(x) all(size(x) == [1 3]) && all(x >= 0) && all(x <= 1) && isnumeric(x)); 
addParameter(arg, 'fig', false, @(x) islogical(x) && (numel(x) == 1));
addParameter(arg, 'verbose', true, @(x) islogical(x) && (numel(x) == 1));

parse(arg, X, label, varargin{:});

% check point and label size consistency
if size(X,1) ~= size(label,1)
    
    error('X and label arrays do not have consistent dimensions.');
    
end

% check number of output arguments
nargoutchk(0, 3);


%% reassign label values

% select labelled points only
N = size(X,1);
idxl_labelled = (label ~= 0);
X = X(idxl_labelled,:);
label = label(idxl_labelled);
[label, ~] = grp2idx(label);


%% compute adjacency

% no labelled points
if ~any(idxl_labelled)
    
    fprintf('Warning: no labelled points.\n');
    color = ones(size(X,1), 1, 'uint8');
    
    switch nargout
        
        case 1
            
            varargout{1} = color;
        
        case 2
            
            varargout{1} = color;
            varargout{2} = arg.Results.unlabelledColor(color,:);
            
        case 3
            
            varargout{1} = color;
            varargout{2} = arg.Results.unlabelledColor(color,:);
            varargout{3} = arg.Results.unlabelledColor;
            
    end
    
    return
    
end

% rasterize
switch arg.Results.adjacency
    
    case '2d'
        
        [~, ~, idxn_cell] = unique(round(X(:,1:2) / arg.Results.buffer) * arg.Results.buffer, 'rows');
        
    case '3d'
        
        [~, ~, idxn_cell] = unique(round(X / arg.Results.buffer) * arg.Results.buffer, 'rows');
        
end

% find unique labels in each voxel
Y = accumarray(idxn_cell, label, [], @(x) {unique(x)}, {nan});

% number of adjacent nodes in each voxel
n_adj = cellfun(@numel, Y);

% define graph edges
idxl_adj = n_adj > 1;
cliques = Y(idxl_adj);

% find all possible node pairs (combinations)
pairs = cell2mat(cellfun(@(x1) nchoosek(x1,2), cliques, 'UniformOutput', false));

% no adjacent clusters
if isempty(pairs)
    
    fprintf('Warning: no adjacent clusters, assigning same color to all\n')
    color = uint8(idxl_labelled + 1);
    cmap = [arg.Results.unlabelledColor; 0.8235, 0.4196, 0.4039];
    
    switch nargout
        
        case 1
            
            varargout{1} = color;
            
        case 2
            
            varargout{1} = color;
            varargout{2} = cmap(color,:);
            
        case 3
            
            varargout{1} = color;
            varargout{2} = cmap(color,:);
            varargout{3} = cmap;
            
    end
    
    return
    
else
    
    % define adjacency matrix
    n_clusters = length(unique(label));
    
    A = false(n_clusters);
    linearInd = sub2ind(size(A), [pairs(:,1); pairs(:,2)], [pairs(:,2); pairs(:,1)]);
    A(linearInd) = true;

    % create graph structure
    G = struct;
    
    % add nodes
    G.Nodes.Label = unique(label); 
    
    % add edges
    [row, col] = find(triu(A));
    G.Edges.EndNodes = sortrows([row, col], 1);
    
end

%% reorder nodes by degree

if arg.Results.verbose
    
    fprintf('reordering nodes by degree...');
    tic
    
end

G.Nodes.Degree = sum(A, 1)'; % compute degree of nodes
[~, idxn_sort] = sort(G.Nodes.Degree, 'descend');

% reorder nodes
G.Nodes = structfun(@(x) x(idxn_sort), G.Nodes, 'UniformOutput', false);

% reorder edges
[~, Locb] = ismember(G.Edges.EndNodes, idxn_sort);
G.Edges.EndNodes = sortrows(sort(Locb, 2), [1 2]);

if arg.Results.verbose
    
    fprintf('done!\n');
    toc
    
end


%% assign color index to graph nodes

if arg.Results.verbose
    
    fprintf('assigning color index to graph nodes...');
    tic
    
end

n = size(A,1); %G.numnodes;
G.Nodes.Color = zeros(n,1, 'uint8');
n_colors = min(G.Nodes.Degree(1), 256);

% traverse nodes
for k = 1:n
    
    %idxn_adj = neighbors(G2, k);
    idxn_adj = [G.Edges.EndNodes(G.Edges.EndNodes(:,2) == k, 1); G.Edges.EndNodes(G.Edges.EndNodes(:,1) == k, 2)];
    
    idxn_color_adj = unique(G.Nodes.Color(idxn_adj));  % color index in node neighbourhood
    
    if isempty(idxn_color_adj)
        
        idxn_color_max = 0;
        
    else
        
        idxn_color_max = idxn_color_adj(length(idxn_color_adj)); % max color index in node neighbourhood
        
    end
    
    idxn_color_pool = setdiff(1:idxn_color_max, idxn_color_adj);
    
    if isempty(idxn_color_pool)
        
        if idxn_color_max > n_colors % error, color pool is empty
            
            error('\nToo many adjacent clusters');
            
        else
            
            G.Nodes.Color(k) = idxn_color_max + 1; % increment color index
            
        end
        
    else
        
        G.Nodes.Color(k) = min(idxn_color_pool); % use min color index avaiable in pool
        
    end
    
end

m = length(unique(G.Nodes.Color));

if arg.Results.verbose
    
    fprintf('done!\n');
    toc
    
end


%% assign color index to 3D points

if arg.Results.verbose
    
    fprintf('assigning color index to points...');
    tic
    
end

[idxl_sample_lab, locb_sample] = ismember(label, G.Nodes.Label);

color_cluster = zeros(nnz(idxl_labelled), 1, 'uint8');
color_cluster(idxl_sample_lab) = G.Nodes.Color(locb_sample(idxl_sample_lab));

color = zeros(N, 1, 'uint8');
color(idxl_labelled) = color_cluster;

if arg.Results.verbose
    
    fprintf('done!\n');
    toc
    
end


%% compute RGB colors

if arg.Results.verbose
    
    fprintf('assigning RGB colors to points...');
    tic
    
end

switch arg.Results.colormap
   
    case 'hsv' % M distinct colors (default Matlab HSV colormap)
        
        cmap = hsv(m);
    
    case 'cmap12' % 12 distinct colors - source: http://colorbrewer2.org/#type=qualitative&scheme=Paired&n=12

        cmap = [166,206,227;
            31,120,180;
            178,223,138;
            51,160,44;
            251,154,153;
            227,26,28;
            253,191,111;
            255,127,0;
            202,178,214;
            106,61,154;
            255,255,153;
            177,89,40] ./ 255;

        color(color > 12) = mod(color(color > 12), 12)+1;
        
    case 'cmap25' % 25 distinct colors - source: http://tools.medialab.sciences-po.fr/iwanthue/
        
        cmap = [210,107,103;
            93,192,62;
            202,72,221;
            179,180,58;
            105,71,213;
            87,165,89;
            217,62,166;
            91,169,149;
            216,75,41;
            74,48,146;
            214,143,60;
            152,66,174;
            149,147,78;
            106,123,212;
            137,75,35;
            97,163,203;
            202,52,82;
            65,87,41;
            201,129,214;
            206,149,124;
            72,74,119;
            199,80,133;
            111,47,51;
            192,144,181;
            117,49,107] ./ 255;
        
        color(color >= 25) = mod(color(color >= 25), 25)+1;
        
end

if m > size(cmap,1)
    
   warning('Number of available colors in chosen colormap (%u) is smaller than required (%u)', size(cmap,1), m)
   
end

% append neutral (unlabelled) color to colormap
if any(~idxl_labelled)
    
    cmap = [arg.Results.unlabelledColor; cmap];
    color = color + 1;
    
end

rgb = cmap(color, :);

if arg.Results.verbose
    
    fprintf('done!\n');
    toc
    
end


%% assign optional output arguments

switch nargout
    
    case 1
        
        varargout{1} = color;
    
    case 2
        
        varargout{1} = color;
        varargout{2} = rgb;
        
    case 3
        
        varargout{1} = color;
        varargout{2} = rgb;
        varargout{3} = cmap;
        
end

%% plot figures

if arg.Results.fig

    switch size(X,2)
        
        case 2
            
            figure
            scatter(X(:,1), ...
                X(:,2), ...
                6, ...
                rgb(idxl_labelled,:), ...
                'Marker', '.')
            axis equal tight
            title('2D point coloring')
            xlabel('x')
            ylabel('y')
            zlabel('z')
            
        case 3
            
            figure
            scatter3(X(:,1), ...
                X(:,2), ...
                X(:,3), ...
                26, ...
                rgb(idxl_labelled,:), ...
                'Marker', '.')
            axis equal tight
            title('3D point coloring')
            xlabel('x')
            ylabel('y')
            zlabel('z')
            
    end
    
end