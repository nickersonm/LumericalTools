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
templateHeader = lsfDir + "10_header_template.lsf";
templateFooter = lsfDir + "90_footer.lsf";

% Define naming
epiName = "LiNbO3";
epiType = "x";
componentName = "WG";

% Epitaxial components
epiScript = lsfDir + "30_epi_" + epiName + "_" + epiType + ".lsf";

% Structure and instrumentation (sources, monitors) definition
etchScript = lsfDir + "20_etch_" + epiName + "_" + epiType + "_" + componentName + ".lsf";
instScript = lsfDir + "40_inst_" + epiName + ".lsf";

% Script naming
scriptName = epiName + "_" + epiType + "_" + componentName;

% Default variable alterations, if any
setVars = {"sim2D", 1};


%% Process
% Assemble script
script = string(fileread(templateHeader)) + "\n\n";
script = script + string(fileread(etchScript)) + "\n\n";
script = script + string(fileread(epiScript)) + "\n\n";
script = script + string(fileread(instScript)) + "\n\n";
script = script + string(fileread(templateFooter));


%% Clean up
clearvars -except script scriptName setVars
