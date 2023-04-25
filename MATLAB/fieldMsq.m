%% fieldMsq.m
%   Michael Nickerson 2023-04-17
%   M^2 calculations for x-normal fields
%       Computed by method in https://doi.org/10.1109/JLT.2005.863337
% 
% Requirements:
%   - 
% 
% Usage: [Msq, MsqY, MsqZ, x0] = fieldMsq(EM, lambda[, option, [value]])
%   Returns:
%     Msq:      Average M^2 value = sqrt(My^2 * Mz^2)
%     MsqY:     M^2 value in y-dimension only
%     MsqZ:     M^2 value in z-dimension only
%     x0y:      Offset from minimum beam waist in y-dimension
%     x0z:      Offset from minimum beam waist in z-dimension
%
%   Parameters:
%     EM:       structure with field 'E' describing an EM field, optionally including 
%                   fields 'x', 'y', 'z'
%     lambda:   wavelength in meters
%
%     Options:
%       none so far
%
% TODO:
%   x Initial development
%   - Test

function [Msq, MsqY, MsqZ, x0y, x0z] = fieldMsq(EM, lambda, varargin)
%% Helper functions, if any
    % Get the next argument or error
    function arg = nextarg(strExpected)
        if isempty(strExpected); strExpected = ''; end
        if ~isempty(varargin)
            arg = varargin{1}; varargin(1) = [];
        else
            error('Expected next argument "%s", but no more arguments present!', strExpected);
        end
    end
    
    % Standardize field
    function f = fieldStd(f)
        % Make 4D if not already; assume anything specified is last dimension
        if numel(size(f.E)) == 2 && size(f.E,2) == 1; f.E = reshape(f.E, [1, 1, numel(f.E)]); end
        if numel(size(f.E)) == 2; f.E = reshape(f.E, [1, size(f.E)]); end
        % Avoid moving scalar field to 4th dimension
        if numel(size(f.E)) == 3 && size(f.E,3) == 3; f.E = reshape(f.E, [1, size(f.E)]); end
        
        % Permute vectors to match if needed
        dims = ["x" "y" "z"];
        d = 1;
        while d < 4
            if isfield(f, dims(d)) && numel(f.(dims(d))) ~= size(f.E,d) && any(numel(f.(dims(d))) == size(f.E))
                dd = find(numel(f.(dims(d))) == size(f.E), d);
                f.E = permute(f.E, [dd, setdiff(1:numel(size(f.E)), dd)]);
                d = 1;  % Restart search
            else
                d = d + 1;
            end
        end
        
        % Create or alter space vectors if needed
        for d = 1:numel(dims)
            % Create if not exist
            if ~isfield(f, dims(d)); f.(dims(d)) = linspace(-1,1,size(f.E,d))'; end
            
            % Resize if mismatched
            if numel(f.(dims(d))) ~= size(f.E, d)
                if size(f.E, d) == 1; f.(dims(d)) = mean(f.(dims(d)));
                else; f.(dims(d)) = linspace(min(f.(dims(d))), max(f.(dims(d))), size(f.E, d)); end
            end
            
            % Require at least 2 points per dimension for assorted calculations
            if numel(f.(dims(d))) == 1
                f.(dims(d)) = f.(dims(d)) + [0; 1]*1e-7;
                r = ones(size(size(f.E))); r(d) = 2;
                f.E = repmat(f.E, r);
            end
        end
    end
    
    % 3D trapz
    function r = trapz3(x, y, z, f)
        % Assume that numel(dim) == 2 means the dimensions have been previously replicated
        %   with a small separation; change that to unit separation
        if numel(x) == 2; x = [0;1]; end
        if numel(y) == 2; y = [0,1]; end
        if numel(z) == 2; z = [0;1]; end

        r = trapz(x, trapz(y, trapz(z, f, 3), 2), 1);
    end


%% Defaults and magic numbers


%% Argument parsing
% Check required inputs
if ~exist("EM", "var") || isempty(EM); Msq = 0; MsqY = 0; MsqZ = 0; return; end
if isa(EM, "double"); EM = struct("E": EM); end
assert( isa(EM, "struct"), '"EM" not a struct');

% Parameter parsing
while ~isempty(varargin)
    arg = lower(varargin{1}); varargin(1) = [];
    
    % Look for valid arguments
    switch arg
        case {'dummy', 'dumb'}
            unused = double(nextarg('dummy argument'));
        otherwise
            if ~isempty(arg)
                warning('Unexpected option "%s", ignoring', num2str(arg));
            end
    end
end


%% Run calculations
% Validate and normalize field
assert( isfield(EM, 'E'), 'No "E" field present in "EM"');
EM = fieldStd(EM);
EM.E = EM.E ./ sqrt(trapz3(EM.x, EM.y, EM.z, sum(abs(EM.E).^2, 4)));
EM.P = sum(abs(EM.E).^2, 4);

% Gridded values
[~, Y, Z] = ndgrid(EM.x, EM.y, EM.z);

% Expectation values
exY = trapz3(EM.x, EM.y, EM.z, Y .* EM.P);
exZ = trapz3(EM.x, EM.y, EM.z, Z .* EM.P);

% Variances
sgYsq = trapz3(EM.x, EM.y, EM.z, (Y - exY).^2 .* EM.P);
sgZsq = trapz3(EM.x, EM.y, EM.z, (Z - exZ).^2 .* EM.P);

% Derivatives
[~, dY, dZ] = ndgrid(gradient(EM.x), gradient(EM.y), gradient(EM.z));
[dEdY, ~, dEdZ] = gradient(EM.E);   % Note row and column output are swapped: first is column, 2nd is row
dEdY = dEdY ./ dY;
dEdZ = dEdZ ./ dZ;

% Field-dot-derivative products
EddY = sum(EM.E .* conj(dEdY), 4); EddY = EddY - conj(EddY);
EddZ = sum(EM.E .* conj(dEdZ), 4); EddZ = EddZ - conj(EddZ);

% A and B parameters
Ay = trapz3(EM.x, EM.y, EM.z, (Y - exY) .* EddY);
Az = trapz3(EM.x, EM.y, EM.z, (Z - exZ) .* EddZ);
By = trapz3(EM.x, EM.y, EM.z, sum(abs(dEdY).^2, 4)) + 0.25 * trapz3(EM.x, EM.y, EM.z, EddY).^2;
Bz = trapz3(EM.x, EM.y, EM.z, sum(abs(dEdZ).^2, 4)) + 0.25 * trapz3(EM.x, EM.y, EM.z, EddZ).^2;

% Final parameters
x0y  = 1i*(pi/lambda)*(Ay/By);
x0z  = 1i*(pi/lambda)*(Az/Bz);
MsqY = sqrt(4*By*sgYsq+Ay^2);
MsqZ = sqrt(4*Bz*sgZsq+Az^2);
Msq = sqrt(MsqY * MsqZ);

end

