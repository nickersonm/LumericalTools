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
epiType = "GaAs";
epiName = "AR8";
componentName = "SSC";

% Epitaxial components
mqwScript = lsfDir + "25_epi_" + epiType + "_MQW.lsf";
epiScript = lsfDir + "30_epi_" + epiType + "_" + epiName + ".lsf";

% Structure and instrumentation (sources, monitors) definition
etchScript = lsfDir + "20_etch_" + epiType + "_WG.lsf";
devScript = lsfDir + "22_etch_" + epiType + "_" + componentName + ".lsf";
instScript = lsfDir + "40_inst_" + epiType + ".lsf";

% Script naming
scriptName = epiType + "_" + epiName + "_" + componentName;

% Default variable alterations, if any
setVars = {"sim2D", 2, "Vpad", 0, "outMFD", 2, "lActive", 0, "aFacet", 0, ...
           "lWG", 5, "lFS", 0.5, "etch1", 3, "etch2", 3, "wWG1", 2.0};


%% Process
% Assemble script
script = string(fileread(templateHeader)) + "\n\n";
script = script + string(fileread(etchScript)) + "\n\n";
script = script + string(fileread(devScript)) + "\n\n";
script = script + string(fileread(mqwScript)) + "\n\n";
script = script + string(fileread(epiScript)) + "\n\n";
script = script + string(fileread(instScript)) + "\n\n";
script = script + string(fileread(templateFooter));


%% Clean up
clearvars -except script scriptName setVars
