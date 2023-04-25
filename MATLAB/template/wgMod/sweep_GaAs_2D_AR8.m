%% Define Lumerical variable sweeps
% Michael Nickerson 2021-07-05
%
% Defines a set of variable values to conduct a sweep
%

clear; %close('all');

%% Build structure
def_GaAs_WG_AR8;


% Define sweep parameters
sweep = {"simY", 6, ...
         "wWG1", linspace(1.5, 5, 15)};
sweepName = "AR8_2D_mod_wWG";
buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
                     'submitjob', 1, 'session', 'lumerical', 'randomize', 0*0.02, ...
                     'submitcmd', ["~/lumerical/Q_selected.sh charge", "~/lumerical/Q_selected.sh fde"]);


%% Build scripts locally
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 0, 'randomize', 0*0.02);
