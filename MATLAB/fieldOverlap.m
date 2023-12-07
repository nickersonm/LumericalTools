%% fieldOverlap.m
%   Michael Nickerson 2022-10-06
%   Index modulation and optical absorption model for GaAs
% 
% Requirements:
%   - 
% 
% Usage: [overlap, o] = fieldOverlap(f1, f2[, option, [value]])
%   Returns:
%     overlap:  complex field overlap, integral(conj(f1) . f2)^2/(integral(|f1|^2)*integral(|f2|^2))
%                   equivalent to S_12^2 * (norm1/norm2)
%     o:        abs(overlap)
%
%   Parameters:
%     f1, f2:   structure with field 'E' describing an EM field, optionally including 
%                   fields 'x', 'y', 'z'; will resample f2 to f1 if needed
%
%     Options:
%       none so far
%
% TODO:
%   x Initial development
%   x Test

function [overlap, o] = fieldOverlap(f1, f2, varargin)
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
if ~exist("f1", "var") || ~exist("f2", "var") || isempty(f1) || isempty(f2); overlap = 0; o = 0; return; end
if isa(f1, "double"); f1 = struct("E", f1); end
if isa(f2, "double"); f2 = struct("E", f2); end
assert( isa(f1, "struct"), '"f1" not a struct');
assert( isa(f2, "struct"), '"f2" not a struct');

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


%% Validate inputs
% f1, f2: structure with field 'E' describing an EM field
assert( isfield(f1, 'E'), 'No "E" field present in "f1"');
assert( isfield(f2, 'E'), 'No "E" field present in "f2"');
f1 = fieldStd(f1);
f2 = fieldStd(f2);

% Convert to scalar if f1 or f2 is scalar
if size(f1.E, 4) ~= 3 || size(f2.E, 4) ~= 3
    f1.E = sum(f1.E, 4); f2.E = sum(f2.E, 4);
end

% Resample if needed
if any(size(f1.E, 1:3) ~= size(f2.E, 1:3)) || any([f1.x(:);f1.y(:);f1.z(:)] ~= [f2.x(:);f2.y(:);f2.z(:)])
    f2.E = interpn(f2.x, f2.y, f2.z, f2.E, f1.x(:), f1.y(:)', f1.z);
    f2.E(isnan(f2.E)) = 0;  % Remove NaNs
    f2.x = f1.x; f2.y = f1.y; f2.z = f1.z;
end

% Calculate complex overlap: integral(conj(f1) . f2)^2/(integral(|f1|^2)*integral(|f2|^2))
N1 = trapz3(f1.x, f1.y, f1.z, sum(abs(f1.E).^2, 4));
N2 = trapz3(f2.x, f2.y, f2.z, sum(abs(f2.E).^2, 4));
overlap = trapz3(f1.x, f1.y, f1.z, sum(conj(f1.E) .* f2.E, 4))^2 / (N1*N2);
o = abs(overlap);

end

