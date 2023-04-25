%% Define Lumerical variable sweeps
% Michael Nickerson 2021-07-05
%
% Defines a set of variable values to conduct a sweep
%

clear; %close('all');

%% Build structure
def_GaAs_WG_AR8;


% Define sweep parameters
% sweep = {"simY", 6, ...
%          "wWG1", linspace(1.5, 5, 15)};
% sweepName = "AR8_2D_passive_wWG";
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 0, 'randomize', 0*0.02);

sweep = {"simY", 5, ...
         "wWG1", [1.5, 2.0, 3.0, 4.0], ...
         "wgBR", [0, linspace(25, 200, 21)]};
sweepName = "AR8_2D_passive_BR";
buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
                     'submitjob', 0, 'randomize', 0*0.02);
