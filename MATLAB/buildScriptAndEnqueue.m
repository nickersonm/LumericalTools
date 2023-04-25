%% buildScriptAndEnqueue.m  MN 2021-07-05
% Build .lsf script from given data and enqueue on given server
% 
% Requirements:
%   - `plink` and `pscp` (from PuTTY) in path with appropriate connection strings
% 
% Usage: status = buildScriptAndEnqueue(name, script, vars, [, option, [value]])
%   Returns:
%     status: Success or failure
%
%   Parameters:
%     name:     script base name
%     script:   nominal .lsf script content
%     vars:     N-length cell of 2M-length cell variable-value pairs to create N modified scripts
%
%     Options:
%       'session', string
%           PuTTY session to use, default 'slurm-host'
%       'plink', string
%           `plink` location if not in PATH, default 'plink'
%       'pscp', string
%           `pscp` location if not in PATH, default 'pscp'
%       'workdir', string
%           temporary working directory, default './tmp'
%       'deletetmp', bool
%           delete temporary files when submitted, default 1
%       'remotedir', string
%           remote working directory, default '~/lumerical/tmp/sweeps'
%       'submitcmd', string or string array
%           remote command(s) to submit script
%           default "~/lumerical/Q_selected.sh fde";
%       'worklog', string
%           logfile for submitted results, default 'submitted.log'
%       'submitjob', bool
%           submit generated scripts, default 0
%       
%
% TODO:
%   x Process options
%   x Build script files from the base and variables
%   x Upload scripts
%   x Enqueue scripts
%   - Determine a better status indicator

function status = buildScriptAndEnqueue(name, script, vars, varargin)
%% Defaults and magic numbers
% Defaults
quiet = 0;
dirCommon = "/home/nickersonm/lumerical/common";
session = "lumerical";
plink = "plink";
pscp = "pscp";

workdir = "./tmp";
deletetmp = 1;
submitjob = 0;
remotedir = "~/lumerical/tmp/sweeps";
submitcmd = "~/lumerical/Q_selected.sh fde";
worklog = "submitted.log";


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
if ~isa(vars, 'cell')   % OK if empty, just run script as is
    error('Required input "vars" is not a cell!');
end

% Allow passing of cells of options
varargin = flatten(varargin);

% Accept a struct.option = value structure
if numel(varargin) > 0 && isstruct(varargin{1})
    paramStruct = varargin{1}; varargin(1) = [];
    varargin = [reshape([fieldnames(paramStruct) struct2cell(paramStruct)]', 1, []), varargin];
end

% Parameter parsing
while ~isempty(varargin)
    arg = lower(varargin{1}); varargin(1) = [];
    
    % Look for valid arguments
    switch arg
        case 'quiet'
            quiet = 1;
        case 'session'
            session = string(nextarg('PuTTY session'));
        case 'plink'
            plink = string(nextarg('`plink` executable'));
        case 'pscp'
            pscp = string(nextarg('`pscp` executable'));
        case {'workdir', 'tmpdir', 'localtmp'}
            workdir = string(nextarg('Local working directory'));
        case {'remotedir', 'remotetmp'}
            remotedir = string(nextarg('Remote working directory'));
        case {'submitcmd', 'cmd'}
            submitcmd = string(nextarg('Remote submission command'));
        case {'deletetmp', 'delete'}
            deletetmp = nextarg('Delete temporary files') > 0;
        case {'log', 'worklog'}
            worklog = string(nextarg('Local submission log'));
        case {'sendjob', 'submitjob', 'submit'}
            submitjob = nextarg('Submit generated scripts') > 0;
        otherwise
            if ~isempty(arg)
                warning('Unexpected option "%s", ignoring', num2str(arg));
            end
    end
end

% Parameter rationalization
deletetmp = deletetmp > 0;
submitjob = submitjob > 0;
if submitjob == 0; deletetmp = 0; end


%% Helper functions, if any
    % Overwrite previous output if passed; quiet if quiet set
    function out = utilDisp(out, varargin)
        if ~quiet
            if numel(varargin) > 0; lastout = varargin{1}; else; lastout = ''; end;
            
            fprintf(repmat('\b', 1, numel(char(sprintf(lastout)))));
            fprintf(out);
        end
    end
    
    % Get the next argument or error
    function arg = nextarg(strExpected)
        if isempty(strExpected); strExpected = ''; end
        if ~isempty(varargin)
            arg = varargin{1}; varargin(1) = [];
        else
            error('Expected next argument "%s", but no more arguments present!', strExpected);
        end
    end
    
    % Flatten a nested cell
    function flatCell = flatten(varargin)
        flatCell = {};
        for j=1:numel(varargin)
            if iscell(varargin{j})
                flatCell = [flatCell flatten(varargin{j}{:})];
            else
                flatCell = [flatCell varargin(j)];
            end
        end
        flatCell = flatCell( ~cellfun(@isempty, flatCell) );
    end
    
    % Generate a modified script
    function script = modScript(script, vars)
        % Replace variables
        for ii=1:2:numel(vars)
            script = regexprep(script, "\n" + vars{ii} + "\s*=.*\n", "\n" + vars{ii} + " = " + vars{ii+1} + ";\n", 'dotexceptnewline');
        end
    end

    % Simplified remote commands
    function out = ssh(cmd)
        [~, out] = system(plink + " -batch -load """ + session + """" + ...
                          " ""export PATH=$PATH:$HOME/bin; " + ...
                          string(cmd) + """");
    end
    function out = scp_out(local, remote, opts)
        if ~exist('opts', 'var'); opts = ""; end
        if contains(remote, "~") || contains(remote, newline)
            % Convert to full path
            remote = ssh("readlink -f """ + remote + """");
            remote = strrep(remote, newline, "");
        end
        [~, out] = system(pscp + " " + opts + " -C -batch -load """ + session + """" + ...
                          " """ + local + """ " + session + ":""" + ...
                          remote + """");
    end


%% Initialization
utilDisp(sprintf("Initializing '%s'...\n", name));

% Verify working folder
if ~isfolder(workdir); mkdir(workdir); end
workdir = what(workdir).path;   % Full path

% Make and convert remote directory to full path
if submitjob > 0
    remotedir = ssh("mkdir -p " + remotedir + "; readlink -f " + remotedir);
    remotedir = strrep(remotedir, newline, "");
end

% Update Lumerical 'common' scripts
if exist('dirCommon', 'var')
    scp_out(dirCommon, "~/lumerical/", "-r");
end

% Open log file
fidLog = fopen(worklog, 'a');


%% Build and submit scripts
% Loop over all input variable-substitution lines
utilDisp("Building and submitting variants...\n\t"); out = "";
for i = 1:numel(vars)
    out = utilDisp(sprintf("%4i/%i", i, numel(vars)), out);
    
    % Generate name and save script
    modName = name + "_" + string(datestr(now, 30)) + "_" + i;
    
    % Get new script, including modified savName and matFile
    mod = modScript(script, [vars{i}, "savName", "'"+modName+"'", "matFile", "'"+modName+".mat'"]);
    modName = modName + ".lsf";
    
    % Write script to temporary file
    fid = fopen(workdir + "/" + modName, 'w');
    fprintf(fid, mod);
    fclose(fid);
    
    % Upload and submit script
    if submitjob > 0
        scp_out(workdir + "/" + modName, remotedir);
        for cmd = submitcmd
            out = out + utilDisp(".");
            ssh(cmd + " " + remotedir + "/" + modName);
        end
        
        % Record submission
        fprintf(fidLog, remotedir + "/" + modName + "\n");
    end
    
    % Delete local script
    if deletetmp; delete(workdir + "/" + modName); end
end


%% Cleanup
% Close log
fclose('all');

utilDisp("\n");

% Check status and close connection
if submitjob > 0
    status = ssh("pueue status | wc -l");
    
    utilDisp(sprintf("Submission of '%s' variants complete!\n", name));
end


end
