%% buildSweepAndEnqueue.m  MN 2022-10-16
%   Preprocessor for buildScriptAndEnque to expand sweep definitions
% 
% Requirements:
%   - `plink` and `pscp` (from PuTTY) in path with appropriate connection strings
% 
% Usage: buildSweepAndEnqueue(name, script, sweep, [, option, [value]])
%   Returns:
%     nothing
%
%   Parameters:
%     name:     script base name
%     script:   nominal .lsf script content
%     sweep:    cell list of variable name and value-range pairs
%
%     Options:
%       'randomize', double
%           randomize varying parameters by this normalized fraction, default 0.05
%       'allvars', cell
%           add these variable-value combinations to all sweeps
%       'sweepname', string
%           name for sweep subdirectory, default empty
%       'session', string
%           PuTTY session to use, default 'lumerical'
%       'deletetmp', bool
%           delete temporary files when submitted, default 1
%       'submitjob', bool
%           submit generated scripts, default 0
%       'submitcmd', string or string array
%           remote command(s) to submit script
%           default "~/lumerical/Q_selected.sh fde";
%       'dircommon', string
%           location of LumericalTools 'common' directory to update remote copy
%       
%
% TODO:
%   - Process options
%   - Expand sweep
%   - Submit sweep

function buildSweepAndEnqueue(name, script, sweep, varargin)
%% Defaults and magic numbers
% Defaults
session = "lumerical";
randomize = 0.05;
dirCommon = "/home/nickersonm/lumerical/common";

sweepname = "";
deletetmp = 1;
submitjob = 0;
submitcmd = "~/lumerical/Q_selected.sh fde";
allvars = {};


%% Argument parsing
% Check required inputs
if isa(name, 'char'); name = string(name); end
if isempty(name) || ~isa(name, 'string')
    error('Required input "name" is not a string!');
end
if isa(script, 'char'); script = string(script); end
if isempty(script) || ~isa(script, 'string')
    error('Required input "script" is not a string!');
end
if ~isa(sweep, 'cell')   % OK if empty, will just run script as is
    error('Required input "sweep" is not a cell!');
end

% Parameter parsing
extraargs = {};
while ~isempty(varargin)
    arg = lower(varargin{1}); varargin(1) = [];
    
    % Look for valid arguments
    switch arg
        case {'randomize', 'rand', 'gaussian', 'variance'}
            randomize = double(nextarg('Sweep name'));
        case {'sweepname', 'name'}
            sweepname = string(nextarg('Sweep name'));
        case 'session'
            session = string(nextarg('PuTTY session'));
        case {'sendjob', 'submitjob', 'submit'}
            submitjob = nextarg('Submit generated scripts') > 0;
        case {'deletetmp', 'delete'}
            deletetmp = nextarg('Delete temporary files') > 0;
        case {'submitcmd', 'cmd'}
            submitcmd = string(nextarg('Remote submission command'));
        case {'allvars', 'allsweeps', 'allvals'}
            allvars = nextarg('All-sweep variables');
        case {'dircommon', 'common', 'commondir'}
            dirCommon = string(nextarg('LumericalTools "common" directory'));
        otherwise
            if ~isempty(arg)
                extraargs = [extraargs, {arg}];
            end
    end
end

% Parameter rationalization
deletetmp = deletetmp > 0;
submitjob = submitjob > 0;
if submitjob == 0; deletetmp = 0; end

% Unpack sweep if needed
if all(cellfun(@iscell, sweep))
    if length(sweep) == 1
        sweep = sweep{1};
    else
        % Recurse
        for s = sweep
            buildSweepAndEnqueue(name, script, s, 'randomize', randomize, 'name', sweepname, ...
                                 'session', session, 'submit', submitjob, ...
                                 'delete', deletetmp, 'cmd', submitcmd, 'allvars', allvars, ...
                                 'dircommon', dirCommon, extraargs);
            dirCommon = ""; % Only update on first copy
        end
    end
end

% Prepend allvars
sweep = [allvars, sweep];

% Parameter checking
sweepsize = prod( arrayfun(@(c) numel(c{:}), sweep(2:2:numel(sweep)) ) );
if sweepsize > 5000
    error("Exceedingly large sweep (%i)! Break up.", sweepsize);
end


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
    
    % Normalize, randomize, and denormalize parameters
    function vals = normrand(vals, weight)
        % Process inputs
        if any(~isnumeric(vals)) || std(vals, [], "all") < 1e-8; return; end
        if ~exist('randomize', 'var') || isempty(weight(1)) || weight(1)==0; return; end
        weight = weight(1);   % Only supports scalar parameter for now
        
        % Normalize vals
        [r1, r2] = bounds(vals, "all");
        vals = (vals - r1) / (r2-r1);
        
        % Apply random bias
        vals = vals + randn(size(vals)) * weight;
        
        % Unnormalize
        vals = vals * (r2-r1) + r1;
    end


%% Expand sweep definition
fprintf("Generating '%s' sweep '%s' (%i entries)...\n", name, sweepname, sweepsize);

% Get all sweep combinations
lvar = sweep(1:2:numel(sweep));   % Variables
lval = cell(size(lvar));          % Values
[lval{:}] = ndgrid(sweep{2:2:numel(sweep)});  % Get all possible value combinations

% Normally randomize and expand to full sweep definition
fullsweep = cell(1, 2*numel(lvar));
fullsweep(:,1:2:end) = cellfun(@(c) repmat(c, numel(lval{1}), 1), lvar, 'un', 0);   % Expand labels
fullsweep(:,2:2:end) = cellfun(@(c) normrand(c(:), randomize), lval, 'un', 0); % Flatten and normalize values

% Convert from 1xN of Mx1 to Mx1 of 1xN
fullsweep = cellfun(@(c) num2cell(c(:)), fullsweep, 'un', 0);
fullsweep = num2cell(horzcat(fullsweep{:}), 2);


%% Submit sweep
if submitjob
    fprintf("Submitting '%s' job '%s' to '%s'...\n", name, sweepname, session);
else
    fprintf("Locally building '%s' job '%s'...\n", name, sweepname);
end    
buildScriptAndEnqueue(name, script, fullsweep, 'workdir', "./sweeps/"+sweepname, ...
                      'submitjob', submitjob, 'deletetmp', deletetmp, 'session', session, ...
                      'submitcmd', submitcmd, 'remotedir', "~/lumerical/tmp/sweeps/"+sweepname, ...
                      'dircommon', dirCommon, extraargs);

end
