%% fieldModeArea.m
%   Michael Nickerson 2023-04-17
%   Effective modal area of given field
% 
% Requirements:
%   - 
% 
% Usage: A = fieldModeArea(EM[, option, [value]])
%   Returns:
%     A:        Effective modal area of field, integral(|E|^2)^2 / integral(|E|^4)
%
%   Parameters:
%     EM:       structure with field 'E' describing an EM field, optionally including 
%                   fields 'x', 'y', 'z'
%
%     Options:
%       none so far
%
% TODO:
%   - Initial development
%   - Test

function A = fieldModeArea(EM, varargin)
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
if isa(EM, "double"); EM = struct("E", EM); end
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

% Calculate effective area
%   https://www.rp-photonics.com/effective_mode_area.html
A = trapz3(EM.x, EM.y, EM.z, sum(abs(EM.E).^2, 4))^2 / trapz3(EM.x, EM.y, EM.z, sum(abs(EM.E).^4, 4));

end

