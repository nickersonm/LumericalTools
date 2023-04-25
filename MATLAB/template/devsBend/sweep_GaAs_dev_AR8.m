%% Define Lumerical variable sweeps
% Michael Nickerson 2021-07-05
%
% Defines a set of variable values to conduct a sweep
%

clear; %close('all');

%% Build structure
def_GaAs_sBend_AR8;


% Define sweep parameters
sweep = {"sim2D", 2, ...
         "wWG1", [2.0, 3.0, 4.0], ...
         "wgBR", [0, linspace(10, 100, 30)]};
sweepName = "AR8_dev_Sbend_varFDTD_1";

% sweep = {"sim2D", 2, ...
%          "wWG1", [2.0, 3.0, 4.0], ...
%          "wgBR", linspace(100, 300, 30)};
% sweepName = "AR8_dev_Sbend_varFDTD_2";


%% Build scripts locally
buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
                     'submitjob', 0, 'randomize', 0*0.02);

%% Build and submit scripts
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 1, 'session', 'lumerical', 'randomize', 0*0.02, ...
%                      'submitcmd', "~/lumerical/Q_selected.sh varfdtd");
