function funStems(cellSize, bandWidth, verticalStep, searchRadius, minLength, par, par_min, par_max, par_step, LASPathIn, PathOut)
  % This script aims to batch process over the same dataset
  % multiple times with varying values of key parameters, like searchradius, bandwidth, etc...
  %
  % Other m-files required: LASread.m, LASwrite.m, rasterize.m, elevationModels.m, canopyPeaks.m,
  % treeWatershed.m, topoColor.m
  % Subfunctions: none
  % MAT-files required: none
  % Compatibility: tested on Matlab R2020b, GNU Octave 6.2.0 (configured for "x86_64-w64-mingw32")
  %
  % Syntax:  [crh, xyh] = canopyPeaks(chm, refmat, method, ...)
  %
  % Inputs:
  %    cellSize (optional, default: 0.4) - numeric value, raster cell size
  %    bandWidth (optional, default: 1.5) - numeric value, raster layer thickness
  %    verticalStep (optional, default: 0.25) - numeric value, vertical shift between successive raster layers
  %    searchRadius (optional, default: 2) - numeric value, radius in map units used for the local density maxima search
  %    minLength (optional, default: 5) - numeric value, minimum layer accumulation length to detect a stem
  %    par - name of the paramater, that one want to test: 'cellSize', 'bandWidth', 'verticalStep', 'searchRadius', 'minLength'
  %    par_min -  min of the range to be explored for the selected parameter par
  %    par_max - max of  the range to be explored ffor the selected parameter par
  %    par_step - step between min and max to test
  %    LAS_PathIn - complete path of input LAS file
  %    File_PathOut - folder path where to write the outputs.
  %
  % Outputs:
  %    SHP - stems location for each tested parameter value
  %    CSV - parameter data saved to a csv file for later use
  %    LAS - labeled and colorized stems in point cloud.
  %
  %
  % Example:
  %    funStems(0.4, 1.5, 0.25, 2, 5, 'cellSize', 0.5, 1, 0.5, 'C:\myLAS.las', 'C:\myOutputFolder\')

  clc
  close all

  OCTAVE_FLAG = (exist('OCTAVE_VERSION', 'builtin') ~= 0); % determine if system is Matlab or GNU Octave
  only_SHP_points_output_FLAG = true

  if OCTAVE_FLAG

      pkg load statistics
      pkg load image

  end


  % Pass function arguments to script variables
  cellSizeDefault = cellSize;
  bandWidthDefault = bandWidth;
  verticalStepDefault = verticalStep;
  searchRadiusDefault = searchRadius;
  minLengthDefault = minLength;
  minVal = par_min;
  maxVal = par_max;
  stepVal = par_step;
  [PathIn FileNameOut] = fileparts(LASPathIn);


  %% Step 1 - Read the LAS file

  pc = LASread(LASPathIn);


  %% Step 2 - Normalize the point cloud elevation

  c1 = fix(clock);
  fprintf('Terrain Model computation started at %d:%d:%d\n', c1(4), c1(5), c1(6));

  % compute the terrain model

  cellSize = 0.5;
  [models, refmat] = elevationModels([pc.record.x, pc.record.y, pc.record.z], ...
      pc.record.classification, ...
      'classTerrain', [2], ...
      'classSurface', [3,4,5], ...
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
  fprintf('Terrain Model computation ended at %d:%d:%d\n', c2(4), c2(5), c2(6));

  if c2(5) < c1(5)
    mins_elapsed = c2(5) - c1(5) + 60;
  else
    mins_elapsed = c2(5) - c1(5);
  end
  fprintf('Approx. time elapsed during Terrain Model computation : %d minutes.\n', mins_elapsed);

  [nrows, ncols] = size(models.terrain.values);

  % subtract the terrain elevation from the point cloud elevation
  P = round([pc.record.x - refmat(3,1), pc.record.y - refmat(3,2)] / refmat(1:2,:));
  ind = sub2ind([nrows, ncols], P(:,1), P(:,2));
  xyh = [pc.record.x, pc.record.y, pc.record.z - models.terrain.values(ind)];


  %% Step 3 - Filter points by classification and return index

  idxl_last = pc.record.return_number == pc.record.number_of_returns; % last returns
  idxl_veg = ismember(pc.record.classification, [3, 4, 5]); % high vegetation class
  idxl_filter = idxl_veg & idxl_last; % combine filters
  %idxl_filter = idxl_veg; % consider all returns instead of only last returns

  %% Write parameter data to a csv file for later use.

  fid = fopen(strcat(PathOut, FileNameOut, '_parameters.csv'), 'w+'); % open file
  fprintf(fid, strcat('Batch identifier : ', FileNameOut, '\n'));
  fprintf(fid, 'Batch stem detection initiated on %d-%d-%d at %d:%d:%d.\n', c2(3), c2(2), c2(1), c2(4), c2(5), c2(6)); % write date and time
  fprintf(fid, 'cellSize,bandWidth,verticalStep,searchRadius,minLength\n'); % write header line
  fprintf(fid, '%f,%f,%f,%f,%f\n', cellSizeDefault, bandWidthDefault, verticalStepDefault, searchRadiusDefault, minLengthDefault);
  fprintf(fid, strcat('Parameter explored,', par,'\n'));
  fprintf(fid, 'Range explored : from %f to %f with steps of %f,%f,%f,%f\n', minVal, maxVal, stepVal, minVal, maxVal, stepVal);
  fclose(fid); % close file

  fprintf('Successfully wrote parameter values to csv file.\n')


  %%%%%%%%%%%%%%%%%%%%%%%%%
  %% START BATCH PROCESS %%
  %%%%%%%%%%%%%%%%%%%%%%%%%

  for parValue = minVal:stepVal:maxVal

    %% Step 4 - Detect stems
    %% We use the correct function based on the parameter chosen.
    %% For example
    %% If cellSize is chosen for par
    %% Then cellSize value is set to the current parValue in the for loop
    %% And the other parameters are set to their default values.

    switch par
      case 'cellSize'
        fprintf('cellSize parameter is being explored, current value is (%f)%f(%f)\n', minVal, parValue, maxVal);

        [label, xyh_stem] = treeStems(xyh, ...
          idxl_filter, ...
          'cellSize', parValue, ...
          'bandWidth', bandWidthDefault, ...
          'verticalStep', verticalStepDefault, ...
          'searchRadius', searchRadiusDefault, ...
          'minLength', minLengthDefault, ...
          'verbose', true, ...
          'fig', false);

      case 'bandWidth'
        fprintf('bandWidth parameter is being explored, current value is (%f)%f(%f)\n', minVal, parValue, maxVal);

        [label, xyh_stem] = treeStems(xyh, ...
          idxl_filter, ...
          'cellSize', cellSizeDefault, ...
          'bandWidth', parValue, ...
          'verticalStep', verticalStepDefault, ...
          'searchRadius', searchRadiusDefault, ...
          'minLength', minLengthDefault, ...
          'verbose', true, ...
          'fig', false);

      case 'verticalStep'
        fprintf('verticalStep parameter is being explored, current value is (%f)%f(%f)\n', minVal, parValue, maxVal);

        [label, xyh_stem] = treeStems(xyh, ...
          idxl_filter, ...
          'cellSize', cellSizeDefault, ...
          'bandWidth', bandWidthDefault, ...
          'verticalStep', parValue, ...
          'searchRadius', searchRadiusDefault, ...
          'minLength', minLengthDefault, ...
          'verbose', true, ...
          'fig', false);

      case 'searchRadius'
        fprintf('searchRadius parameter is being explored, current value is (%f)%f(%f)\n', minVal, parValue, maxVal);

        [label, xyh_stem] = treeStems(xyh, ...
          idxl_filter, ...
          'cellSize', cellSizeDefault, ...
          'bandWidth', bandWidthDefault, ...
          'verticalStep', verticalStepDefault, ...
          'searchRadius', parValue, ...
          'minLength', minLengthDefault, ...
          'verbose', true, ...
          'fig', false);

      case 'minLength'
        fprintf('minLength parameter is being explored, current value is (%f)%f(%f)\n', minVal, parValue, maxVal);

        [label, xyh_stem] = treeStems(xyh, ...
          idxl_filter, ...
          'cellSize', cellSizeDefault, ...
          'bandWidth', bandWidthDefault, ...
          'verticalStep', verticalStepDefault, ...
          'searchRadius', searchRadiusDefault, ...
          'minLength', parValue, ...
          'verbose', true, ...
          'fig', false);

    endswitch


    %% Step 5 - Export stem attributes to a CSV file

    if ~only_SHP_points_output_FLAG

      fid = fopen(strcat(PathOut, FileNameOut, '_stems.csv'), 'w+'); % open file
      fprintf(fid, 'X, Y, H, label\n'); % write header line
      fprintf(fid, '%.2f, %.2f, %.2f, %.0f\n', [xyh_stem unique(label(label>0))]'); % write records
      fclose(fid); % close file

    end


    %% Step 6 - Export stem attributes to an ESRI shapefile

    S = struct('Geometry', repmat({'Point'}, size(xyh_stem,1),1), ...
          'X', num2cell(xyh_stem(:,1)), ...
          'Y', num2cell(xyh_stem(:,2)), ...
          'BoundingBox', [], ...
          'H', num2cell(xyh_stem(:,3)), ...
          'Label', num2cell(unique(label(label>0))));

    % write non-scalar structure to SHP file
    shapewrite(S, strcat(PathOut, FileNameOut, '_', par, '_', strrep(num2str(parValue), '.', 'p'), '_stems.shp'));

    fprintf('One iteration complete\n');

  endfor

##  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
##  %% BATCH PROCESS FINISHED %%
##  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
##
## %%----------------------- Print stems as LAS file ---------------------------
##
##    % duplicate the source file
##    r = pc;
##
##    % add the "label" field to the point record (as an uint32 field)
##    %r.record.label = uint32(mod(label,12)); % modulo to have 13 colours in a ramp
##    r.record.label = uint32(label);
##
##    % transfer the color index
##    color_3d = label;
##    color_3d(label>0) = mod(label(label>0),5)+2;
##    color_3d(label==0) = 1;
##
##    % define a colormap
##    cmap = [NaN, NaN, NaN;
##        166,206,227;
##        31,120,180;
##        178,223,138;
##        51,160,44;
##        251,154,153;
##        227,26,28;
##        253,191,111;
##        255,127,0;
##        202,178,214;
##        106,61,154;
##        255,255,153;
##        177,89,40] ./ 255;
##
##    % rescale the RGB colors to 16 bit range and add them to the point record
##    rgb = uint16(cmap(color_3d,:) * 65535);
##    r.record.red = rgb(:,1);
##    r.record.green = rgb(:,2);
##    r.record.blue = rgb(:,3);
##    %r.record.alpha = uint16((label>0)*65535);
##
##    % CM: since I found no record.alpha field for transparency, artificially put...
##    % everything that is not a stem label in the min corner of the bounding box.
##    xmin = min(pc.record.x(:));
##    ymin = min(pc.record.y(:));
##    zmin = min(pc.record.z(:));
##
##    r.record.x = (label>0).*pc.record.x(:)+(label==0)*xmin;
##    r.record.y = (label>0).*pc.record.y(:)+(label==0)*ymin;
##    r.record.z = (label>0).*pc.record.z(:)+(label==0)*zmin;
##
##    % add the "label" uint32 field metadata in the variable length records
##    % check the ASPRS LAS 1.4 specification for details about the meaning of the fields
##    % https://www.asprs.org/a/society/committees/standards/LAS_1_4_r13.pdf
##    vlr = struct;
##    vlr.value.reserved = 0;
##    vlr.value.data_type = 5;
##    vlr.value.options.no_data_bit = 0;
##    vlr.value.options.min_bit = 0;
##    vlr.value.options.max_bit = 0;
##    vlr.value.options.scale_bit = 0;
##    vlr.value.options.offset_bit = 0;
##    vlr.value.name = 'label';
##    vlr.value.unused = 0;
##    vlr.value.no_data = [0; 0; 0];
##    vlr.value.min = [0; 0; 0];
##    vlr.value.max = [0; 0; 0];
##    vlr.value.scale = [0; 0; 0];
##    vlr.value.offset = [0; 0; 0];
##    vlr.value.description = 'LABEL';
##
##    vlr.reserved = 43707;
##    vlr.user_id = 'LASF_Spec';
##    vlr.record_id = 4;
##    vlr.record_length_after_header = length(vlr.value) * 192;
##    vlr.description = 'Extra bytes';
##
##    % append the new VLR to the existing VLR
##    if isfield(r, 'variable_length_records')
##
##        r.variable_length_records(length(r.variable_length_records)+1) = vlr;
##
##    else
##
##        r.variable_length_records = vlr;
##
##    end
##
##    % if necessary, adapt the output record format to add the RGB channel
##    switch pc.header.point_data_format_id
##
##        case 1 % 1 -> 3
##
##            recordFormat = 3;
##
##        case 4 % 4 -> 5
##
##            recordFormat = 5;
##
##        case 6 % 6 -> 7
##
##            recordFormat = 7;
##
##        case 9 % 9 -> 10
##
##            recordFormat = 10;
##
##        otherwise % 2,3,5,7,8,10
##
##            recordFormat = pc.header.point_data_format_id;
##
##    end
##
##    % write the LAS 1.4 file
##    % IMPORTANT: adjust the path to the output LAS file
##    LASwrite(r, ...
##        strcat(PathOut, FileNameOut, '_', par, '_', strrep(num2str(parValue), '.', 'p'), '_stems.las'),...
##        'version', 14, ...
##        'guid', lower(strcat(dec2hex(randi(16,32,1)-1)')), ...
##        'systemID', 'SEGMENTATION', ...
##        'recordFormat', recordFormat, ...
##        'verbose', true);



  fprintf('PROGRAM ENDED SUCCESSFULLY\n');
  clear all


end


