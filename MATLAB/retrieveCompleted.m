%% retrieveCompleted.m  MN 2021-07-13
% Retreive products of 'buildScriptAndEnqueue' from remote server
% 
% Requirements:
%   - `plink` and `pscp` (from PuTTY) in path with appropriate connection strings
% 
% Usage: status = retrieveCompleted([option, [value]])
%   Returns:
%     status: Success or failure
%
%   Parameters:
%
%     Options:
%       'name', string
%           Only process files starting with this name
%       'worklog', string
%           logfile for submitted results, default 'submitted.log'
%       'session', string
%           PuTTY session to use, default 'lumerical'
%       'plink', string
%           `plink` location if not in PATH, default 'plink'
%       'pscp', string
%           `pscp` location if not in PATH, default 'pscp'
%       'workdir', string
%           temporary working directory, default './tmp'
%       'delete', bool
%           delete remote files after retreival, default 1
%       'sortlocal', bool
%           attempt to sort local files in to subdirectories corresponding 
%           to base name before timestamp, default 1
%       'matonly', bool
%           only retreive *.mat files and delete others, default 1
%       
%
% TODO:
%   x Process options
%   x Search and download
%   x Delete

function status = retrieveCompleted(varargin)
%% Defaults and magic numbers
% Defaults
status = 0;
quiet = 0;

session = "lumerical";
plink = "plink";
pscp = "pscp";

scriptname = '';
worklog = "submitted.log";
workdir = "./tmp";
deleteremote = 1;
sortlocal = 1;
matonly = 1;


%% Argument parsing
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
        case {'name', 'scriptname'}
            scriptname = string(nextarg('File name prefix'));
        case {'deleteremote', 'delete'}
            deleteremote = nextarg('Delete remote files after transfer') > 0;
        case {'sort', 'sortlocal'}
            sortlocal = nextarg('Sort local files into subdirectories') > 0;
        case {'log', 'worklog'}
            worklog = string(nextarg('Local submission log'));
        case {'matonly', 'onlymat'}
            matonly = nextarg('Only retreive *.mat files') > 0;
        otherwise
            if ~isempty(arg)
                warning('Unexpected option "%s", ignoring', num2str(arg));
            end
    end
end


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

    % Simplified remote commands
    function out = ssh(cmd)
        [~, out] = system(plink + " -batch -load """ + session + """" + ...
                          " ""export PATH=$PATH:$HOME/bin; " + ...
                          string(cmd) + """");
    end
    function out = scp_in(remote, local)
        if contains(remote, "~") || contains(remote, newline)
            % Convert to full path
            remote = ssh("readlink -f """ + remote + """");
            remote = strrep(remote, newline, "");
        end
        [~, out] = system(pscp + " -batch -load """ + session + """ " + ...
                          session + ":""" + remote + """ """ + ...
                          local + """");
    end


%% Initialization
% Verify local log file
if ~isfile(worklog)
    fprintf("Unable to find local log '%s', aborting.\n", worklog);
    return;
end
utilDisp(sprintf("Processing submission log '%s'...\n", worklog));

% Verify working folder
if ~isfolder(workdir); mkdir(workdir); end
workdir = what(workdir).path + "/";   % Full path

% Backup log file and read
movefile(worklog, worklog + ".bak", "f");
filelog = readmatrix(worklog + ".bak", "FileType", "text", "OutputType", "string", "Delimiter", "");
% filelog = readmatrix(worklog, "FileType", "text", "OutputType", "string", "Delimiter", "");


%% Process each line
utilDisp("\t"); out = "";
for i = 1:numel(filelog)
    out = utilDisp(sprintf("%4i/%i", i, numel(filelog)), out);
    
    % Process file name
    [remotepath, basename, fileext] = fileparts(filelog(i));
    if fileext ~= ".lsf"
        % Somehow a non-script file ended up in this list; skip
        warning("\nUnknown file '%s'; skipping.", basename+fileext);
        continue;
    end
    
    % Skip if matched filename requested and no match
    if ~isempty(char(scriptname))
        if ~startswith(basename, scriptname)
            continue;
        end
    end
    
    % Make sure remote script is done processing - only one .lsf
    if str2double(ssh("ls " + remotepath + "/" + basename + "*.lsf | wc -l")) > 1
        % Still processing, or error in processing - leave alone
        warning("\n'%s' appears to still be processing; skipping.", basename+fileext);
        continue;
    end
    
    % Determine local subdirectory
    localpath = workdir;
    if sortlocal > 0
        localpath = workdir + regexprep(basename, "^(.*)_\d{8}T.*$", "$1") + "/";
        if ~isfolder(localpath); mkdir(localpath); end
    end
    
    % Desired remote files
    rext = "*";
    if matonly > 0
        rext = rext + ".mat";
    end
    
    % Enumerate remote files
    remotefiles = ssh("ls -1 " + remotepath + "/" + basename + rext);
    remotefiles = regexprep(remotefiles, "(^.*No such.*$|^\n)", "");
    remotefiles = splitlines(string(remotefiles));
    remotefiles(remotefiles == "") = [];    % Remove empty lines
    if isempty(remotefiles) || all(remotefiles == "")
        filelog(i) = "";
        warning("\nNo remote files found for '%s'; skipping.", basename+rext);
        continue;
    end
    
    % Copy remote files
    scp_in(remotepath + "/" + basename + rext, localpath);
    
    % Verify local presence
    [~, lfiles, lexts] = fileparts(remotefiles);
    if ~all(isfile(localpath + lfiles + lexts))
        warning(sprintf("\nMissing local file: %s; skipping log entry", lfiles(~isfile(localpath + lfiles + lexts))));
        continue;
    end
    
    % Delete remote files and remove this entry from the log
    if deleteremote; ssh("rm " + remotepath + "/" + basename + "*"); end
    filelog(i) = "";
end


%% Cleanup
utilDisp("\n");

% Remove empty lines
filelog(filelog == "") = [];

% Write unprocessed lines back to worklog and delete backup
if ~isempty(filelog)
    writematrix(filelog, worklog, "WriteMode", "append", "FileType", "text", "Delimiter", " ");
end
delete(worklog + ".bak");

utilDisp(sprintf("Processing of submission log '%s' complete!\n", worklog));


end
