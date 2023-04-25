%% Define Lumerical variable sweeps
% Michael Nickerson 2021-07-05
%
% Defines a set of variable values to conduct a sweep
%

clear; %close('all');

%% Build structure
def_GaAs_EulerU_AR8;


% Define sweep parameters
sweep = {"sim2D", 2, ...
         "wWG1", [1.5, 2.0], ...
         "wgBR", [logspace(log10(2), log10(40), 30)]};
sweepName = "AR8_passive_EulerU_wgBR_varFDTD";

% sweep = {"sim2D", 0, "simAccuracy", 3, ...
%          "wWG1", [1.5, 2.0], ...
%          "wgBR", [logspace(log10(2), log10(20), 20)]};
% sweepName = "AR8_passive_EulerU_wgBR_FDTD";


%% Build scripts locally
buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
                     'submitjob', 0, 'randomize', 0*0.02);
