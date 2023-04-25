%% Define Lumerical variable sweeps
% Michael Nickerson 2021-07-05
%
% Defines a set of variable values to conduct a sweep
%

clear; %close('all');

%% Build structure
def_GaAs_MMI_AR8;

%% MMI: 1x1 deep
def_GaAs_MMI_AR8;
sweep = {"N", 1, "dlMMI", linspace(-15, 8.5, 11)};
sweepName = "AR8_passive_MMI_1x1_deep_dl";
buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
                     'submitjob', 0, 'randomize', 0);

% %% MMI: 1x2 deep
% def_GaAs_MMI_AR8;
% sweep = {"N", 2, "dlMMI", linspace(-18, -10.5, 11)};
% sweepName = "AR8_passive_MMI_1x2_deep_dl";
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 0, 'randomize', 0);

% %% MMI: 1x3 deep
% def_GaAs_MMI_AR8;
% sweep = {"N", 3, "wMMI", "2*(wSpace + wWG1)", "lMMI", "lPi/4", "dlMMI", linspace(-20, -10.5, 11)};
% sweepName = "AR8_passive_MMI_1x3_deep_dl";
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 0, 'randomize', 0);

% %% MMI: 1x4 deep
% def_GaAs_MMI_AR8;
% sweep = {"N", 4, "dlMMI", linspace(-25, 14.5, 11)};
% sweepName = "AR8_passive_MMI_1x4_deep_dl";
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 0, 'randomize', 0);


%% Large wavelength sweep for 1x2 and 1x4
% sweep = {"wWG1", 1.5, "lPi", "(4 * nr * wMMI^2 ) / ( 3 * 1.03 )", ...
%          "N", 2, "dlMMI", -9, "lambda", linspace(0.80, 1.4, 150)};
% sweepName = "AR8_passive_MMI_1x2_deep_varFDTD_lambda";
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 0, 'randomize', 0);

% sweep = {"wWG1", 1.5, "lPi", "(4 * nr * wMMI^2 ) / ( 3 * 1.03 )", ...
%          "N", 4, "dlMMI", -10, "lambda", linspace(0.80, 1.4, 150)};
% sweepName = "AR8_passive_MMI_1x4_deep_varFDTD_lambda";
% buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
%                      'submitjob', 0, 'randomize', 0);
