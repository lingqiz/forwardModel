function setbounds(obj)
% Sets the bounds on the model parameters
%
% Syntax:
%   obj.setbounds()
%
% Description:
%   Bounds for the prf_timeShift model. Rationale is as follows:
%       x, y :  Stimulus edges +-50%
%       sigma:  1/2 stimulus width
%       gain :  Positive values only
%       exp  :  Locked to 0.05, following Benson et al, 2018, HCP 7T data
%       shift:  HRF temporal shift +- 3 seconds.       
%
%   These are specified as 1 x nParams vectors.
%
% Inputs:
%   none
%
% Optional key/value pairs:
%   none
%
% Outputs:
%   none
%


% Obj variables
res = obj.res;
nParams = obj.nParams;

% Define outputs
lb = nan(1,nParams);
ub = nan(1,nParams);

% The lower bounds
lb(1) = -res(1)/4;      % xPosition
lb(2) = -res(2)/4;      % yPosition
lb(3) = 0.1;            % sigma
lb(4) = 0;              % gain (amplitude) of response
lb(5) = 0.05;           % compressive exponent
lb(6) = -3;             % HRF temporal shift (seconds)

% The upper bounds
ub(1) = 1.25*res(1);    % xPosition
ub(2) = 1.25*res(2);    % yPosition
ub(3) = max(res)/2;     % sigma
ub(4) = 1000;           % gain (amplitude) of response
ub(5) = 0.05;           % compressive exponent
ub(6) = 3;              % HRF temporal shift (seconds)

% Store the bounds in the object
obj.lb = lb;
obj.ub = ub;

% Store the minParamDelta for the model
paramResolution = nan(1,nParams);
paramResolution(1,:) = [0.1 .1 .1 realmin realmin realmin];
obj.paramResolution = paramResolution;

end
