function transforms = wtransform(data, tiling, outlierFactor, ...
               analysisMode, channelNames, coefficients, coordinate)
% WTRANSFORM Compute the discrete coherent Q transform of the data
%
% WTRANSFORM applies the discrete Q transform described by the
% predetermined tiling structure to frequency domain data from
% multiple detectors, potentially after transformation into a new
% basis of virtual data streams for coherent analysis.  The tiling
% structure contains the transform parameters and is generated by the
% WTILE function.  The input data should be the fourier transform of
% the time series data to be analyzed.  However, the input frequency
% series should only extend from zero frequency to the Nyquist
% frequency.  As a result, the input frequency series should be of
% length N / 2 + 1, where N is the length of the original input time
% series.
%
% usage: transforms = wtransform(data, tiling, outlierFactor, ...
%               analysisMode, channelNames, coefficients, coordinate);
%
% The following input variables are required:
%
%   data                 cell array of input frequency series data
%   tiling               discrete Q tranform tiling structure from WTILE
%   outlierFactor        Tukey whisker multiplier for outlier rejection
%   analysisMode         what type of analysis to do
%   channelNames         cell array of single detector channel names
%   coefficients         cell array of filter coefficients from WCONDITION
%   coordinate           sky position
%
% If just the first three or four parameters are present, an
% analysisMode of 'independent' is assumed or required.
%
% The output is:
%
%   transforms           cell array of discrete Q transform structures
%
% The sky position should be specified as a two component vector of
% the form [theta phi] as used by WTILESKY and WSKYMAP.  The
% coordinate theta is a geocentric colatitude running from 0 at the
% North pole to pi at the South pole, and the coordinate phi is the
% geocentric longitude in Earth fixed coordinates with 0 on the prime
% meridian.  The units are radian, the range of theta is [0, pi] and
% the range of phi is [0, 2 pi).
%
% The resulting discrete Q transform structures are parallel to the structure
% returned by WTILE and contain the following supplemental fields for each
% frequency row.
%
%   meanEnergy            mean of tile energies
%   normalizedEnergies    vector of normalized tile energies
%
% See also WTILE, WCONDITION, WTHRESHOLD, WSELECT, and WSEARCH.

% ***** See documentation for QH1H2.
% ***** This requires modifying WEVENTGRAM to also display incoherent energies.

% Shourov K. Chatterji <shourov@ligo.mit.edu>
% Antony C. Searle <acsearle@ligo.caltech.edu>
% Jameson Rollins <jrollins@phys.columbia.edu>

% $Id: wtransform.m 2753 2010-02-26 21:33:24Z jrollins $

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                  process/validate command line arguments                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% verify correct number of input arguments
error(nargchk(3, 7, nargin, 'struct'));

% infer analysis type from missing arguments and
% construct default arguments
if (nargin < 4) || isempty(analysisMode),
  analysisMode = 'independent';
end
if (nargin < 5),
  channelNames = [];
end
if (nargin < 6) || isempty(coefficients),
  if ~any(strcmpi(analysisMode, {'independent'})),
    error('further inputs required for coherent analysis modes')
  end
  coefficients = [];
end
if (nargin < 7) || isempty(coordinate),
  coordinate = [pi/2,0];
end

% validate tiling structure
if ~strcmp(tiling.id, 'Discrete Q-transform tile structure'),
  error('input argument is not a discrete Q transform tiling structure');
end

if ~any(strcmpi(analysisMode, {'independent', 'coherent'})),
  error('unknown analysis mode "%s"\n', analysisMode)
end

% force cell arrays
data = wmat2cell(data);
channelNames = wmat2cell(channelNames, ~isempty(channelNames));
coefficients = wmat2cell(coefficients, ~isempty(coefficients));

% force one dimensional cell arrays
data = data(:);
channelNames = channelNames(:);
coefficients = coefficients(:);

% determine number of channels
numberOfChannels = length(data);

% check channel names exist
if isempty(channelNames)
  if strcmp(analysisMode,'independent')
    % provide default channel names
    channelNames = cell(numberOfChannels, 1);
    for channelNumber = 1:numberOfChannels,
      channelNames{channelNumber} = ['X' int2str(channelNumber)];
    end
  else
    % must supply channel names for coherent analyses that need them for
    % antenna patterns
    error('must provide channelNames for coherent analysis');
  end
end

% check coefficients exist
if isempty(coefficients)
  if strcmp(analysisMode,'independent')
    % provide default coefficients
    coefficients = cell(numberOfChannels, 1);
    for channelNumber = 1:numberOfChannels,
      coefficients{channelNumber} = ones(size(data{channelNumber}));
    end
  else
    % must supply coefficients for coherent analyses that need them for
    % response matrix
    error('must provide coefficients for coherent analysis');
  end
end

% determine required data lengths
dataLength = tiling.sampleFrequency * tiling.duration;
halfDataLength = dataLength / 2 + 1;

% validate data length and force row vectors
for channelNumber = 1 : numberOfChannels,
  data{channelNumber} = data{channelNumber}(:).';
  if length(data{channelNumber}) ~= halfDataLength,
    error('data length not consistent with tiling');
  end
end

% validate number of coefficients vectors
if length(coefficients) ~= numberOfChannels,
    error('coefficients are inconsistent with number of channels');
end

% validate coefficients length and force row vectors
for channelNumber = 1 : numberOfChannels,
    coefficients{channelNumber} = coefficients{channelNumber}(:).';
    if length(coefficients{channelNumber}) ~= halfDataLength,
        error('coefficients length not consistent with tiling');
    end
end

% determine number of sites
sites = unique(regexprep(channelNames, '.:.*$', ''));
numberOfSites = length(sites);

% validate channel names
if ~isempty(channelNames) && (length(channelNames) ~= numberOfChannels),
    error('channel names are inconsistent with number of transform channels');
end

% ensure collocated network if it was implied by omitting coordinate
if nargin == 5 && numberOfSites ~= 1
    error('coordinate must be provided for non-collocated networks');
end

if strcmp(analysisMode, 'coherent'),
  if numberOfChannels < 2,
    error('not enough channels for a coherent analysis (>2 required)');
  end
end
    
% force coordinate row vector
coordinate = coordinate(:).';

% validate coordinate vector
if length(coordinate) ~= 2,
    error('coordinates must be a two component vector [theta phi]');
end

% extract spherical coordinates                  % ***** currently unused *****
theta = coordinate(:, 1);                        % ***** currently unused *****
phi = coordinate(:, 2);                          % ***** currently unused *****

% validate spherical coordinates                 % ***** currently unused *****
if (theta < 0) || (theta > pi),                  % ***** currently unused *****
    error('theta outside of range [0, pi]');     % ***** currently unused *****
end                                              % ***** currently unused *****
if (phi < 0) || (phi >= 2 * pi),                 % ***** currently unused *****
    error('phi outside of range [0, 2 pi)');     % ***** currently unused *****
end                                              % ***** currently unused *****

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         setup analysis modes                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
switch lower(analysisMode)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                       setup independent analysis                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 case {'independent'}

  intermediateData = data;
  numberOfIntermediateChannels = numberOfChannels;
  numberOfOutputChannels = numberOfChannels;
  outputChannelNames = channelNames;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                        setup coherent analysis                          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 case {'coherent'}

  % determine detector antenna functions and time delays
  [fplus, fcross, deltat] = wresponse(coordinate, channelNames);

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %                    time shift detector data                         %
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % use first-listed detector as time reference (this has the advantage of
  % making collocated work naturally)
  deltat = deltat - deltat(1);

  % frequency vector
  frequency = 0 : (1/tiling.duration) : tiling.sampleFrequency / 2;

  % time shift data by frequency domain phase shift
  for channelNumber = 1 : numberOfChannels,
    data{channelNumber} = data{channelNumber} .* ...
                          exp(sqrt(-1) * 2 * pi * frequency * ...
                              deltat(channelNumber));
  end

  % clear unecessary frequency vector
  clear frequency;

  % concatenated list of detector identifiers
  detectors = [];
  for channelNumber = 1 : numberOfChannels,
    detectors = [detectors channelNames{channelNumber}(1:2)];
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %                     construct new basis                             %
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % form the response matrix
  responseMatrix = [fplus; fcross]';

  % Simple basis (not taking into account power spectrum) is useful tool to
  % understand structure of the SVD
  %
  % [u,s,v] = svd(responseMatrix);
  %
  % If s(2,2) does not exist or is zero we are insensitive to the 
  % second polarization and we can compute only the primary signal component 
  % and N - 1 null streams
  %
  % If s(2,2) exists and is nonzero, we can compute the primary 
  % and secondary signal components and N - 2 null streams

  % preallocate the coefficient structure
  basis = cell(numberOfChannels);
  for i = 1:numberOfChannels
    for j = 1:numberOfChannels
      basis{i,j} = zeros(size(coefficients{1}));
    end
  end

  % preallocate the responseMatrix for a given frequency
  f = zeros(size(responseMatrix));

  %for each frequency bin
  for frequencyNumber = 1:halfDataLength,
      % for each channel form the response matrix including the noise
      % coefficients
      for channelNumber = 1:numberOfChannels,
        f(channelNumber,:) = responseMatrix(channelNumber,:) .* ...
            coefficients{channelNumber}(frequencyNumber);
      end
      % compute the singular value decomposition
      [u, s, v] = svd(f);

      % repack the orthonormal basis coefficients into the output 
      % structure
      for i = 1:numberOfChannels
        for j = 1:numberOfChannels
          basis{i,j}(frequencyNumber) = u(i,j);
        end
      end
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %                          setup coherent outputs                     %
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  intermediateData = cell(numberOfChannels);
  for i = 1:numberOfChannels,
    for j = 1:numberOfChannels
      intermediateData{i,j} = basis{i,j} .* data{i};
    end
  end
    
  % free the memory associated with the input data
  clear data;
    
  %setup output metadata
  numberOfIntermediateChannels = numberOfChannels^2;

  numberOfOutputChannels = 2;
  outputChannelNames{1} = [detectors ':SIGNAL-COHERENT'];
  outputChannelNames{2} = [detectors ':SIGNAL-INCOHERENT'];
    
  % output null stream if network allows
  if (numberOfSites >= 3) || (numberOfChannels > numberOfSites),
    numberOfOutputChannels = 4;
    outputChannelNames{3} = [detectors ':NULL-COHERENT'];
    outputChannelNames{4} = [detectors ':NULL-INCOHERENT'];
  end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                              otherwise error                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 otherwise

  error(['unknown analysis mode: ' analysisMode]);
   
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                          end setup analysis modes                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                      initialize Q transform structures                       %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% create empty cell array of Q transform structures
transforms = cell([1,numberOfOutputChannels]);

% begin loop over channels
for outputChannelNumber = 1 : numberOfOutputChannels,

  % insert structure identification string
  transforms{outputChannelNumber}.id = 'Discrete Q-transform transform structure';

  % create empty cell array of Q plane structures
  transforms{outputChannelNumber}.planes = cell(size(tiling.planes));

  % begin loop over Q planes
  for plane = 1 : tiling.numberOfPlanes,

    % create empty cell array of frequency row structures
    transforms{outputChannelNumber}.planes{plane}.rows = ...
        cell(size(tiling.planes{plane}.numberOfRows));

  % end loop over Q planes
  end

% end loop over channels
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                           begin loop over Q planes                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% begin loop over Q planes
for plane = 1 : tiling.numberOfPlanes,

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %                      begin loop over frequency rows                        %
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % begin loop over frequency rows
  for row = 1 : tiling.planes{plane}.numberOfRows,

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %               extract and window frequency domain data                   %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % number of zeros to pad at negative frequencies
    leftZeroPadLength = (tiling.planes{plane}.rows{row}.zeroPadLength - 1) / 2;

    % number of zeros to pad at positive frequencies
    rightZeroPadLength = (tiling.planes{plane}.rows{row}.zeroPadLength + 1) / 2;

    % begin loop over channels
    for intermediateChannelNumber = 1 : numberOfIntermediateChannels,

      % extract and window in-band data
      windowedData{intermediateChannelNumber} = tiling.planes{plane}.rows{row}.window .* ...
          intermediateData{intermediateChannelNumber}(tiling.planes{plane}.rows{row}.dataIndices);

      % zero pad windowed data
      windowedData{intermediateChannelNumber} = [zeros(1, leftZeroPadLength) ...
                               windowedData{intermediateChannelNumber} ...
                               zeros(1, rightZeroPadLength)];

      % reorder indices for fast fourier transform
      windowedData{intermediateChannelNumber} = ...
          windowedData{intermediateChannelNumber}([(end / 2 : end) (1 : end / 2 - 1)]);

    % end loop over channels
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %               inverse fourier transform windowed data                    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % begin loop over channels
    for intermediateChannelNumber = 1 : numberOfIntermediateChannels,

        % complex valued tile coefficients
        tileCoefficients{intermediateChannelNumber} = ifft(windowedData{intermediateChannelNumber});

    % end loop over channels
    end 

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %              energies directly or indirectly                   %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    switch lower(analysisMode)
     case {'independent'}

      % compute energies directly from intermediate data
      for channelNumber = 1:numberOfIntermediateChannels
        energies{channelNumber} = ...
          real(tileCoefficients{channelNumber}).^2 + ...
          imag(tileCoefficients{channelNumber}).^2 ;
      end

     case {'coherent'}
      
      % compute coherent and incoherent energies indirectly from
      % intermediate data
      for outerChannelNumber = 1:numberOfChannels
          % coherent stream energy    
          accumulatedTileCoefficients = zeros(size(tileCoefficients{1}));    
          for channelNumber = 1:numberOfChannels,
              accumulatedTileCoefficients = accumulatedTileCoefficients + tileCoefficients{channelNumber + (outerChannelNumber - 1) * numberOfChannels};
          end
          energies{1 + (outerChannelNumber - 1) * 2} = real(accumulatedTileCoefficients).^2 + imag(accumulatedTileCoefficients).^2;

          % incoherent stream energy
          energies{2 + (outerChannelNumber - 1) * 2} = zeros(size(energies{1}));
          for channelNumber = 1:numberOfChannels,
              energies{2 + (outerChannelNumber - 1) * 2} = energies{2 + (outerChannelNumber - 1) * 2}...
                  + real(tileCoefficients{channelNumber + (outerChannelNumber - 1) * numberOfChannels}).^2 ...
                  + imag(tileCoefficients{channelNumber + (outerChannelNumber - 1) * numberOfChannels}).^2;
          end
      end
      
      % accumulate in corresponding channels
      
      if numberOfSites > 1
        % the second group of channels is the unwanted secondary signal
        % energy, so zero it out
        energies{3} = zeros(size(energies{3}));
        energies{4} = zeros(size(energies{4}));
      end
      
      % sum all the null energies into a single channel
      for channelNumber = 3:numberOfChannels
        energies{3} = energies{3} + energies{1 + (channelNumber - 1) * 2};
        energies{4} = energies{4} + energies{2 + (channelNumber - 1) * 2};
      end
      
    end
          
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %        exclude outliers and filter transients from statistics            %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    times = (0 :  tiling.planes{plane}.rows{row}.numberOfTiles - 1) * ...
             tiling.planes{plane}.rows{row}.timeStep;

    % begin loop over channels
    for outputChannelNumber = 1 : numberOfOutputChannels,

      % indices of non-transient tiles
      validIndices{outputChannelNumber} = ...
          find((times > ...
                tiling.transientDuration) & ...
               (times < ...
                tiling.duration - tiling.transientDuration));

      % identify lower and upper quartile energies
      sortedEnergies = ...
          sort(energies{outputChannelNumber}(validIndices{outputChannelNumber}));
      lowerQuartile{outputChannelNumber} = ...
          sortedEnergies(round(0.25 * length(validIndices{outputChannelNumber})));
      upperQuartile{outputChannelNumber} = ...
          sortedEnergies(round(0.75 * length(validIndices{outputChannelNumber})));

      % determine inter quartile range
      interQuartileRange{outputChannelNumber} = upperQuartile{outputChannelNumber} - ...
                                          lowerQuartile{outputChannelNumber};

      % energy threshold of outliers
      outlierThreshold{outputChannelNumber} = upperQuartile{outputChannelNumber} + ...
          outlierFactor * interQuartileRange{outputChannelNumber};

      % indices of non-outlier and non-transient tiles
      validIndices{outputChannelNumber} = ...
          find((energies{outputChannelNumber} < ...
                outlierThreshold{outputChannelNumber}) & ...
               (times > ...
                tiling.transientDuration) & ...
               (times < ...
                tiling.duration - tiling.transientDuration));

    % end loop over channels
    end

    % for reasonable outlier factors,
    if outlierFactor < 100,

      % mean energy correction factor for outlier rejection bias
      meanCorrectionFactor = (4 * 3^outlierFactor - 1) / ...
                             ((4 * 3^outlierFactor - 1) - ...
                             (outlierFactor * log(3) + log(4)));

    % otherwise, for large outlier factors
    else

      % mean energy correction factor for outlier rejection bias
      meanCorrectionFactor = 1;

    % continue
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %          determine tile statistics and normalized energies               %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % begin loop over channels
    for outputChannelNumber = 1 : numberOfOutputChannels,

      % mean of valid tile energies
      meanEnergy{outputChannelNumber} = ...
          mean(energies{outputChannelNumber}(validIndices{outputChannelNumber}));

      % correct for bias due to outlier rejection
      meanEnergy{outputChannelNumber} = meanEnergy{outputChannelNumber} * ...
          meanCorrectionFactor;

      % normalized tile energies
      normalizedEnergies{outputChannelNumber} = energies{outputChannelNumber} / ...
          meanEnergy{outputChannelNumber};

    % end loop over channels
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %               insert results into transform structure                    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % begin loop over channels
    for outputChannelNumber = 1 : numberOfOutputChannels,

      % insert mean tile energy into frequency row structure
      transforms{outputChannelNumber}.planes{plane}.rows{row}.meanEnergy = ...
          meanEnergy{outputChannelNumber};

      % insert normalized tile energies into frequency row structure
      transforms{outputChannelNumber}.planes{plane}.rows{row}.normalizedEnergies = ...
          normalizedEnergies{outputChannelNumber};
      
    % end loop over channels
    end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %                       end loop over frequency rows                         %
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % end loop over frequency rows
  end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                            end loop over Q planes                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% end loop over Q planes
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    return discrete Q transform structure                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for channelNumber = 1 : numberOfOutputChannels,
    transforms{channelNumber}.channelName = ...
        outputChannelNames{channelNumber};
end    

% return to calling function
return
