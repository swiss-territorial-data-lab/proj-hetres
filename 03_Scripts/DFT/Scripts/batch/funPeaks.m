function funPeaks(pc, minTreeHeight_min, minTreeHeight_max, minTreeHeight_step, cellSize, method_peaks, myFun, LASPathIn, PathOut)
  % This script aims to batch process over the same dataset
  % multiple times with varying values of key parameters, like searchradius, bandwidth, etc...
  %
  % Other m-files required: LASread.m, LASwrite.m, rasterize.m, elevationModels.m, canopyPeaks.m,
  % treeWatershed.m, topoColor.m
  % Subfunctions: none
  % MAT-files required: none
  % Compatibility: tested on Matlab R2020b, GNU Octave 6.2.0 (configured for "x86_64-w64-mingw32")
  %
  % Syntax:  [] = funPeaks(minTreeHeight_min, minTreeHeight_max, minTreeHeight_step, cellSize, method_peaks, myFun, LASPathIn, PathOut)
  %
  % Inputs:
  %    minTreeHeight_min -  min of the range to be explored for the minimum tree top height
  %    minTreeHeight_max - max of  the range to be explored for the minimum tree top height
  %    minTreeHeight_step - step between min and max to test
  %    method_peaks - choice between 'default' and 'hmax', see canopyPeaks.m
  %    LASPathIn - entire path of input LAS file
  %    PathOut - folder path where to write the output files
  %
  % Outputs:
  %    SHP - peaks location for each tested parameter value
  %    CSV - parameter data saved to a csv file for later use
  %    LAS - labeled and colorized segments in point cloud
  %
  % Example:
  %
  %    funPeaks(2, 15, 13, 0.8, 'default', myFun, 'C:\myLAS.las', 'C:\myOutputFolder\')



  % Source: Matlab Digital Forestry Toolbox
    % Author: Matthew Parkan, EPFL - GIS Research Laboratory
    % Website: http://mparkan.github.io/Digital-Forestry-Toolbox/
    % Last revision: April 4, 2021
    % Acknowledgments: This work was supported by the Swiss Forestry and Wood Research Fund (WHFF, OFEV), project 2013.18
    % Licence: GNU General Public Licence (GPL), see https://www.gnu.org/licenses/gpl.html for details

  clc
  close all

  OCTAVE_FLAG = (exist('OCTAVE_VERSION', 'builtin') ~= 0); % determine if system is Matlab or GNU Octave

  if OCTAVE_FLAG

      pkg load statistics
      pkg load image
      more off

  end


  % Pass function arguments to script variables
  minVal = minTreeHeight_min;
  maxVal = minTreeHeight_max;
  stepVal = minTreeHeight_step;
  [PathIn FileNameOut] = fileparts(LASPathIn); % Used to create multiple files with same name and different extension.


  %% Step 1 - Reading the LAS file

  %pc = LASread(LASPathIn);


  %% Step 2 - Computing a raster Canopy Height Model (CHM)
  %% elevationModels is a script inside scripts\grids

  c1 = fix(clock);
  fprintf('Terrain Model computation started at %d:%d:%d\n', c1(4), c1(5), c1(6));

  [models, refmat] = elevationModels([pc.record.x, pc.record.y, pc.record.z], ...
      pc.record.classification, ...
      'classTerrain', [2], ...
      'classSurface', [3,4,5], ...
      'cellSize', cellSize, ...
      'interpolation', 'idw', ...
      'searchRadius', 10, ... %change to 10 to make it faster, initial value inf
      'weightFunction', @(d) d^-3, ...
      'smoothingFilter', fspecial('gaussian', [3, 3], 0.8), ...
      'outputModels', {'terrain', 'surface', 'height'}, ...
      'fig', false, ...
      'verbose', true);

  c2 = fix(clock);
  fprintf('Terrain Model computation ended at %d:%d:%d\n', c2(4), c2(5), c2(6));

  if c2(5) < c1(5)
    mins_elapsed = c2(5) - c1(5) + 60;
  else
    mins_elapsed = c2(5) - c1(5);
  end
  fprintf('Approx. time elapsed during Terrain Model computation : %d minutes.\n', mins_elapsed);

  %% Write parameter data to a csv file for later use.

  fid = fopen(strcat(PathOut, FileNameOut, '_parameters.csv'), 'w+'); % open file
  fprintf(fid, strcat('Batch identifier : ', FileNameOut, '\n'));
  fprintf(fid, 'Batch peak detection initiated on %d-%d-%d at %d:%d:%d.\n', c2(3), c2(2), c2(1), c2(4), c2(5), c2(6)); % write date and time
  fprintf(fid, 'Parameter explored,minTreeHeight\n');
  fprintf(fid, 'Range explored : from %f to %f with steps of %f,%f,%f,%f\n', minVal, maxVal, stepVal, minVal, maxVal, stepVal);
  fclose(fid); % close file

  fprintf('Successfully wrote parameter values to csv file.\n')



  %%%%%%%%%%%%%%%%%%%%%%%%%
  %% START BATCH PROCESS %%
  %%%%%%%%%%%%%%%%%%%%%%%%%

  %% Step 4 - Batch Tree top detection

  for minTreeHeight = minVal:stepVal:maxVal

    fprintf('minTreeHeight parameter is being explored, current value is (%f)%f(%f)\n', minVal, minTreeHeight, maxVal);

    %% canopyPeaks is a script inside scripts\canopy metrics
    [peaks_crh, ~] = canopyPeaks(models.height.values, ...
        refmat, ...
        'method', method_peaks, ...
        'minTreeHeight', minTreeHeight, ... % minimum tree top height
        'searchRadius', myFun, ... %0.28 * h^0.59, ...
        'minHeightDifference', 0.1, ... % 0.1, 0.3
        'fig', false, ...
        'verbose', true);

    %% Step 5 - Marker controlled watershed segmentation
    %% treeWatershed is a script inside scripts\tree metrics

    [label_2d, colors] = treeWatershed(models.height.values, ...
        'markers', peaks_crh(:,1:2), ...
        'minHeight', 2, ... % minimum canopy height (what is considered as being part of canopy.
        'removeBorder', true, ...
        'fig', false, ...
        'verbose', true);


    %% Step 6 - Computing segment metrics from the label matrix

    % IMPORTANT: some of the metrics in regionprops() are currently only available in Matlab
    metrics_2d = regionprops(label_2d, models.height.values, ...
        'Area', 'Centroid', 'MaxIntensity');


    %% Step 7 - Transferring 2D labels to the 3D point cloud

    idxl_veg = ismember(pc.record.classification, [3,4,5]);

    % convert map coordinates (x,y) to image coordinates (column, row)
    RC = [pc.record.x - refmat(3,1), pc.record.y - refmat(3,2)] / refmat(1:2,:);
    RC(:,1) = round(RC(:,1)); % row
    RC(:,2) = round(RC(:,2)); % column
    ind = sub2ind(size(label_2d), RC(:,1), RC(:,2));

    % transfer the label
    label_3d = label_2d(ind);
    label_3d(~idxl_veg) = 0;
    [label_3d(label_3d ~= 0), ~] = grp2idx(label_3d(label_3d ~= 0));

    % transfer the color index
    color_3d = colors(ind);
    color_3d(~idxl_veg) = 1;

    % define a colormap
    cmap = [0, 0, 0;
        166,206,227;
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

    %% Step 9 - Computing segment metrics from the labelled point cloud

    % compute metrics
    [metrics_3d, fmt, idxl_scalar] = treeMetrics(label_3d, ...
        [pc.record.x, pc.record.y, pc.record.z], ...
        pc.record.intensity, ...
        pc.record.return_number, ...
        pc.record.number_of_returns, ...
        nan(length(pc.record.x), 3), ...
        models.terrain.values, ...
        refmat, ...
        'metrics', {'UUID', 'LUID','XPos', 'YPos', 'ZPos', 'H','BBOX2D', 'XCVH2D', 'YCVH2D', 'CVH2DArea', 'IQ50'}, ...
        'intensityScaling', true, ...
        'alphaMin', 1.5, ...
        'verbose', true);

    % list field names
    sfields = fieldnames(metrics_3d);

    %% Step 11 - Exporting the segment points (and metrics) to a SHP file

    % duplicate the metrics structure (scalar fields only)
    S1 = rmfield(metrics_3d, sfields(~idxl_scalar));

    % add the geometry type
    [S1.Geometry] = deal('Point');

    % add the X coordinates of the polygons
    [S1.X] = metrics_3d.XPos;

    % add the Y coordinates of the polygons
    [S1.Y] = metrics_3d.YPos;

    % add the label to the shape


    shapewrite(S1,strcat(PathOut, FileNameOut, '_mTH_', strrep(num2str(minTreeHeight), '.', 'p'), '_peaks.shp'));%

    clear S1

    fprintf('One iteration complete\n');




   %%------------------ Exporting the labelled and colored point cloud to a LAS file----------------

    % duplicate the source file
    r = pc;

    % ,rescale the RGB colors to 16 bit range and add them to the point record
    rgb = uint16(cmap(color_3d,:) * 65535);
    r.record.red = rgb(:,1);
    r.record.green = rgb(:,2);
    r.record.blue = rgb(:,3);

    % add the "label" field to the point record (as an uint32 field)
    r.record.label = uint32(label_3d);

    % add the "label" uint32 field metadata in the variable length records
    % check the ASPRS LAS 1.4 specification for details about the meaning of the fields
    % https://www.asprs.org/a/society/committees/standards/LAS_1_4_r13.pdf
    vlr = struct;
    vlr.value.reserved = 0;
    vlr.value.data_type = 5;
    vlr.value.options.no_data_bit = 0;
    vlr.value.options.min_bit = 0;
    vlr.value.options.max_bit = 0;
    vlr.value.options.scale_bit = 0;
    vlr.value.options.offset_bit = 0;
    vlr.value.name = 'label';
    vlr.value.unused = 0;
    vlr.value.no_data = [0; 0; 0];
    vlr.value.min = [0; 0; 0];
    vlr.value.max = [0; 0; 0];
    vlr.value.scale = [0; 0; 0];
    vlr.value.offset = [0; 0; 0];
    vlr.value.description = 'LABEL';

    vlr.reserved = 43707;
    vlr.user_id = 'LASF_Spec';
    vlr.record_id = 4;
    vlr.record_length_after_header = length(vlr.value) * 192;
    vlr.description = 'Extra bytes';

    % append the new VLR to the existing VLR
    if isfield(r, 'variable_length_records')

        r.variable_length_records(length(r.variable_length_records)+1) = vlr;

    else

        r.variable_length_records = vlr;

    end

    % if necessary, adapt the output record format to add the RGB channel
    switch pc.header.point_data_format_id

        case 1 % 1 -> 3

            recordFormat = 3;

        case 4 % 4 -> 5

            recordFormat = 5;

        case 6 % 6 -> 7

            recordFormat = 7;

        case 9 % 9 -> 10

            recordFormat = 10;

        otherwise % 2,3,5,7,8,10

            recordFormat = pc.header.point_data_format_id;

    end

    % write the LAS 1.4 file
    % IMPORTANT: adjust the path to the output LAS file
    LASwrite(r, ...
        strcat(PathOut, FileNameOut, '_mTH_', strrep(num2str(minTreeHeight), '.', 'p'), '_seg.las'), ...
        'version', 14, ...
        'guid', lower(strcat(dec2hex(randi(16,32,1)-1)')), ...
        'systemID', 'SEGMENTATION', ...
        'recordFormat', recordFormat, ...
        'verbose', true);


  end



  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% BATCH PROCESS FINISHED %%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%





  fprintf('PROGRAM ENDED SUCCESSFULLY\n');
  clear all

end
