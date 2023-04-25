%% Define Lumerical variable sweeps
% Michael Nickerson 2021-07-05
%
% Defines a set of variable values to conduct a sweep
%

clear; %close('all');

%% Build structure
def_GaAs_1D_AR8;


%% Define sweep parameters
% sweep = {"tG", 0.10:0.05:0.60};
% sweepName = "AR8_active_tG";
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 0, 'randomize', 0*0.05);

sweep = {"lActive", 0, "Vpad", -10, ...
         "tG", 0.10:0.05:0.6};
sweepName = "AR8_mod_tG";
buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
                     'submitjob', 1, 'session', 'lumerical', 'randomize', 0*0.02, ...
                     'submitcmd', ["~/lumerical/Q_selected.sh charge", "~/lumerical/Q_selected.sh fde"]);

% sweep = {"lActive", [0, 10]};
% sweepName = "AR8_AP";
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 0, 'randomize', 0*0.05);
