function results = forwardModel(data,stimulus,tr,varargin)
% Non-linear model fitting of fMRI time-series data
%
% Syntax:
%  results = forwardModel(data,stimulus,tr)
%
% Description:
%   Framework for non-linear fitting of parameterized models to fMRI
%   time-series data. The fMRI data are passed as a voxel x time matrix;
%   the stimulus is specified in a matrix with the temporal domain as the
%   last dimension. Data and stimuli from multiple acquisitions may be
%   passed in as a cell array of matrices. The stimulus may have a
%   different temporal resolution than the data, in which case the
%   key-value stimTime defines the mapping between stimulus and data. All
%   voxels in the data are processed unless a subset are specified in the
%   key-value vxs.
%
%   The key-value modelClass determines the model to be fit to the data.
%   Each model is implemented as an object oriented class within the models
%   directory. The behavior of the model may be controlled by passing
%   modelOpts, and by passing additional materials in the modelPayload.
%
%   This framework is inspred by, and many of the underlying utility
%   functions taken from, Kendrick Kay's analyzePRF toolbox:
%       https://github.com/kendrickkay/analyzePRF
%
% Inputs:
%   data                  - A matrix [v t] or cell array of such
%                           matricies. The fMRI time-series data across t
%                           TRs, for v vertices / voxels.
%   stimulus              - A matrix in which the last dimension is the
%                           time domain of the stimulus. The precise form
%                           of the stimulus matrix is determined by the
%                           particular model that is to be fit. A typical
%                           form is [x y st], which provides the property
%                           of the stimulus in the x-y domain of the
%                           stimulus display over stimulus time. The input
%                           may also be a cell array of such matrices. If
%                           the stimulus time (st) is different in length
%                           than the data time (t), a valid stimTime
%                           key-value must be passed (see below).
%   tr                    - Scalar. The TR of the fMRI data in seconds.
%
% Optional key/value pairs:
%  'modelClass'           - Char vector. The name of one of the available
%                           model objects. Choices include:
%                             {'prfTimeShift','flobsHRF','gammaHRF'}
%  'modelOpts'            - A cell array of key-value pairs that are passed
%                           to the model object at that time of object
%                           creation. For example:
%                               {'typicalGain',300}
%  'modelPayload'         - A cell array of additional inputs that is
%                           passed to the model object. The form of the
%                           payload is defined by the model object.
%  'stimTime'             - [1 st] vector or cell array of such vectors
%                           provides the temporal support for the stimulus
%                           matrix (or matrices) in units of seconds. Time
%                           should be defined relative to the start of the
%                           first TR of each acquisition. Stimulus events
%                           prior to the onset of the first TR of an
%                           acquisition can be indicated by negative time
%                           values.
%  'vxs'                  - Vector. A list of vertices/voxels to be
%                           processed. If not specified, all rows of the
%                           data matrix will be analyzed.
%  'averageVoxels'        - Logical. If set to true, all time series (or 
%                           the subset specified by vxs) are averaged prior
%                           to model fitting.
%  'silenceWarnings'      - Logical. Silences warnings regarding imperfect
%                           model fitting.
%  'verbose'              - Logical.
%
% Outputs:
%   results               - Structure. The contents are determined by the
%                           results method in each model.
%
% Examples:
%   See the "demo.m" files within each model
%


%% input parser
p = inputParser; p.KeepUnmatched = false;

% Required
p.addRequired('data',@(x)(iscell(x) || ismatrix(x)));
p.addRequired('stimulus',@(x)(iscell(x) || ismatrix(x)));
p.addRequired('tr',@(x)(isscalar(x) && ~isnan(x)));

p.addParameter('modelClass','prfTimeShift',@ischar);
p.addParameter('modelOpts',{},@iscell);
p.addParameter('modelPayload',{},@iscell);
p.addParameter('stimTime',{},@(x)(iscell(x) || ismatrix(x)));
p.addParameter('vxs',[],@isvector);
p.addParameter('averageVoxels',false,@islogical);
p.addParameter('silenceWarnings',true,@islogical);
p.addParameter('verbose',true,@islogical);

% parse
p.parse(data,stimulus,tr, varargin{:})

verbose = p.Results.verbose;
silenceWarnings = p.Results.silenceWarnings;

%% Alert the user
if verbose
    fprintf(['\nFitting the ' p.Results.modelClass ' model.\n\n']);
end


%% Check inputs and set constants
% Place the data and stimulus in a cell if not already so
if ~iscell(data)
    data = {data};
end
if ~iscell(stimulus)
    stimulus = {stimulus};
end

% Confirm that the data and stimulus cell arrays are of the same length
if length(data) ~= length(stimulus)
    error('forwardModel:inputMismatch','Different number of acquisitions specified in the data and stimulus variables');
end

% Make sure stimTime is a cell vector. If not defined, create a cell array
% of empty vectors equal to the number of stimulus matrices.
if ~isempty(p.Results.stimTime)
    if ~iscell(p.Results.stimTime)
        stimTime = {p.Results.stimTime};
    else
        stimTime = p.Results.stimTime;
    end
    % Make sure that the length of the stimTime cell array is the same as
    % the length of the stimulus cell array
    if length(stimTime) ~= length(stimulus)
        error('forwardModel:inputMismatch','Different number of acquisitions specified in the stimTime and stimulus variables');
    end
else
    stimTime = p.Results.stimTime;
end

% The first dimension of the data matrix indexes across voxels/vertices
totalVxs = size(data{1},1);

% Define vxs (the voxel/vertex set to process)
if isempty(p.Results.vxs)
    vxs = 1:length(totalVxs);
else
    vxs = p.Results.vxs;
end


%% Set up model
% Create the model object
model = feval(p.Results.modelClass,data,stimulus,p.Results.tr,...
    'stimTime',stimTime, ...
    'payload',p.Results.modelPayload, ...
    p.Results.modelOpts{:});

% Set model verbosity
model.verbose = verbose;

% Prep the raw data
data = model.prep(data);

% Handle averageVoxels
if p.Results.averageVoxels
    % In each acquisition, create the average time series across the vxs
    % voxels, skipping those voxels that have been set to have uniform zero
    % values by the prep stage
    for ii = 1:length(data)
        nonZeroVxs = ~all(data{ii}(vxs,:)==0,2);
        averagets = mean(data{ii}(vxs(nonZeroVxs),:),1);
        data{ii}(vxs,:)=repmat(averagets,length(vxs),1);
    end
    % Retain the full set of vxs
    fullVxs = vxs;
    vxs = vxs(1);
end

% Generate seeds
seeds = model.seeds(data,vxs);


%% Fit the data

nVxs = length(vxs);

% Convert the data into a single, concatenated matrix of [totalVxs time]
data = catcell(1,data);

% Retain just the voxels to be processed
data = data(vxs,:);

% Basic options for fmincon
basicOptions = optimoptions('fmincon','Display','off');

% Pre-compute functions that will asemble the parameters in the different
% model stages, and create different option sets
for bb = 1:model.nStages
	order = [model.floatSet{bb} model.fixSet{bb}];
	[~,sortOrder]=sort(order);
	xSort{bb} = @(x) x(sortOrder);
    stageOptions = basicOptions;
    stageOptions.FiniteDifferenceStepSize = ...
        model.FiniteDifferenceStepSize(model.floatSet{bb});
    options{bb} = stageOptions;
end

% Obtain the model bounds
lb = model.lb; ub = model.ub;

% Alert the user
if verbose
    if nVxs==1
        fprintf(['Fitting model over one vertex.\n']);
    else
        fprintf(['Fitting model over ' num2str(nVxs) ' vertices.\n']);
    end
    
    % If this is deployed code, update the progress once every 5 minutes,
    % as the progress bar updates accumulate in the log
    if isdeployed
        UpdateRate = 1/300;
        fprintf(['Updates every ' num2str(1/UpdateRate) ' seconds./n']);
    else
        UpdateRate = 5;
    end
    
    % Instantiate the progress bar object with the 'Parallel' switch set to
    % true and save the aux files in the current working directory (pwd)
    pbarObj = ProgressBar(nVxs, ...
        'IsParallel', true, ...
        'WorkerDirectory', pwd, ...
        'Title', p.Results.modelClass, ...
        'UpdateRate', UpdateRate ...
        );
    pbarObj.setup([], [], []);
    
    % Start a timer
    tic
end


% Store the warning state
warningState = warning;

% Loop through the voxels/vertices in vxs
parfor ii=1:nVxs
    
    % Silence warnings if so instructed. This must be done inside the par
    % loop to apply to each worker.
    if silenceWarnings
        warning('off','MATLAB:singularMatrix');
        warning('off','MATLAB:nearlySingularMatrix');
        warning('off','MATLAB:illConditionedMatrix');
    end

    % Update progress bar
    if verbose
        updateParallel([], pwd);
    end
    
    % Get the time series for the selected voxel/vertex, transpose to a
    % column vector (time x 1)
    datats = data(ii,:)';
    
    % Apply the model cleaning step, which may include regression of
    % nuisance components
    datats = model.clean(datats);
    
    % Pre-allocate the seed search result variables to keep par happy
    seedParams = nan(length(seeds),model.nParams);
    seedMetric = nan(length(seeds),1);
    
    % Loop over seed sets
    for ss = 1:length(seeds)
        seed = seeds{ss}(vxs(ii),:);
        x0 = seed;

        % Loop over model stages
        for bb = 1:model.nStages
            
            % Get the params in the fix and float set for this stage
            fixSet = model.fixSet{bb};
            floatSet = model.floatSet{bb};

            % Define an anonymous function as a non-linear constraint
            nonlcon = @(x) model.nonlcon(xSort{bb}([x x0(fixSet)]));
            
            % Define an anonymous function as an objective
            myObj = @(x) model.objective(datats,(xSort{bb}([x x0(fixSet)])));
            
            % Call the non-linear fit function
            x = fmincon(myObj,x0(floatSet),[],[],[],[], ...
                lb(floatSet),ub(floatSet), ...
                nonlcon, options{bb});
            
            % Update the x0 guess with the searched params
            x0(model.floatSet{bb}) = x;
        end
        
        % Store the final params
        seedParams(ss,:) = x0;
        
        % Evaluate the model metric
        seedMetric(ss) = model.metric(datats,x0);
    end
    
    % Save the best result across seeds
    [~,bestSeedIdx]=max(seedMetric);
    parParams(ii,:) = seedParams(bestSeedIdx,:);
    parMetric(ii) = seedMetric(bestSeedIdx);
    
end


% Report completion of loop
if verbose
    pbarObj.release();
    toc
    fprintf('\n');
end

% Restore the warning state. It shouldn't be changed at the main execution
% level since warnings were silenced within the worker pool, but restoring
% here to be safe.
warning(warningState);

% Handle averageVoxels
if p.Results.averageVoxels
    % Expand the params and metric out to all of vxs
    parParams = repmat(parParams,length(fullVxs),1);
    parMetric = repmat(parMetric,length(fullVxs),1);
    vxs = fullVxs;
end

% Map the par variables into full variables
params = nan(totalVxs,model.nParams);
params(vxs,:) = parParams;
clear parParams
metric = nan(totalVxs,1);
metric(vxs) = parMetric;
clear parMetric;


%% Prepare the results variable
results = model.results(params, metric);

% Add the model information
results.model.class = p.Results.modelClass;
results.model.inputs = {stimulus, p.Results.tr};
if isempty(stimTime)
    stimTime = {stimTime};
end
results.model.opts =  [p.Results.modelOpts 'stimTime' stimTime];
results.model.payload =  p.Results.modelPayload;

% Store the calling options
results.meta.vxs = vxs;
results.meta.tr = p.Results.tr;

% Add plots to the results
results = model.plot(data, results);

end