function x0 = initial(obj)
% Returns initial guess for the model parameters
%
% Syntax:
%   x0 = obj.initial()
%
% Description:
%   Initial values for the deriveHRF model.
%
% Inputs:
%   none
%
% Optional key/value pairs:
%   none
%
% Outputs:
%   x0                    - 1xnParams vector.
%


% Obj variables
typicalGain = obj.typicalGain;
nParams = obj.nParams;

% Assign the x0 variable
x0 = zeros(1,nParams);

% Assemble X0
x0(1) = 6;              % gamma1 (seconds)
x0(2) = 12;             % gamma2 (seconds)
x0(3) = 10;             % gammaScale
x0(4) = typicalGain;    % typical gain (amplitude)
x0(5) = 20;             % duration (seconds)

end
