%% Define Lumerical construction script for structure
% Michael Nickerson 2021-07-05
%
% Creates script by merging:
%   templateHeader
%   structScript
%   epiScript
%   instScript
%   templateFooter
%

clear; %close('all');

%% Definitions
% Common components
lsfDir = "../lsf/";
template = lsfDir + "99_MQW_peaks.lsf";

% Define naming
scriptName = "MQW_peaks";

% Default variable alterations, if any
setVars = {"resultFile", "'" + scriptName + ".dat'", "mqwRecord", 0};


%% Process
% Assemble script
script = string(fileread(template));


%% Clean up
clearvars -except script scriptName setVars
