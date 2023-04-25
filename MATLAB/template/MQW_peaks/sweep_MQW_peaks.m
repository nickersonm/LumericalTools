%% Define Lumerical variable sweeps
% Michael Nickerson 2023-04-25
%
% Defines a set of variable values to conduct a sweep
%

clear; %close('all');

%% Build structure
def_MQW_peaks;


%% Define sweep parameters
% sweep = {"Nqw", [3 4]};
% sweepName = "MQW_nominal_N";

sweep = {"cden", linspace(0.1^0.5, 15^0.5, 30).^2};
sweepName = "MQW_nominal_cden";


%% Build scripts locally
buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
                     'submitjob', 0, 'deletetmp', 0, 'randomize', 0);

% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 1, 'session', 'lumerical', 'randomize', 0, ...
%                      'submitcmd', "BUILDONLY=1 ~/lumerical/Q_selected.sh fde");
