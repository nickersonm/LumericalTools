%% Define Lumerical variable sweeps
% Michael Nickerson 2021-07-05
%
% Defines a set of variable values to conduct a sweep
%

clear; %close('all');

%% Build structure
def_GaAs_WG_AR8;


% Define sweep parameters
sweep = {"lActive", 10, ...
         "simY", "wWG1 + 2", "wWG2", 30, ...
         "etch1", linspace(2, 6, 15), "wWG1", linspace(2, 6, 15)};
sweepName = "AR8_2D_active_deep";
buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
                     'submitjob', 0, 'randomize', 0.02);

% sweep = {"lActive", 10, "outMFD", 3, ...
%          "simResFine", 0.1, ...
%          "simY", 30, "dSimZ", "[0, 1]", "wWG2", 40, ...
%          "etch1", linspace(0.5, 3.5, 15), ...
%          "wWG1", linspace(2.5, 6, 15)};
% sweepName = "AR8_2D_active_shallow";
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 0, 'randomize', 0.02);
