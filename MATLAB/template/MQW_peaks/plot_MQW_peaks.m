%% Load, process, and plot simulation result data
% Michael Nickerson 2021-08-02

clear; close('all');


%% Simulation-specific definitions
% Load definitions
def_MQW_peaks; clear script setVars;

% Set customizations
dualMode = 0;
resExts = ".mat";
% sweepName = "MQW_nominal_N";
sweepName = "MQW_nominal_cden";

noPlotParams = ["Peak Rsp [arb]"];
noPlotTogether = ["", ""];
savePlot = 0;
plot1D = 0;


%% Definitions
% Plotting script
baseScript = "sweepPlots_Base.m";
outDir = pwd + "/" + datestr(now, "yyyymmdd") + "/" + sweepName(1) + "/";

componentName = scriptName;

% Files to load
resFiles = [];
for sweep = sweepName
    resFiles = [resFiles; dir("./sweeps/" + sweep + "/" + scriptName+"*.mat")];
end
resFiles = regexprep(string({resFiles.folder}') + "\" + string({resFiles.name}'), "\.mat", "");

% Parameters to plot; needs to evaluate to doubles
params = ["R.mqwStrain", "R.Nqw", "R.cden", ...
          "R.tQW*1e3", "R.tQWB*1e3", "R.xQW"];
pLabels = ["Strain Calculated", "# QW", "Carrier Density [1e18 cm^-3]", ...
           "QW Thickness [nm]", "Barrier Thickness [nm]", "In-fraction QW"];

% Metrics
preComp = "[~,R.peakI] = sort(-R.mqw.emission.spontaneous_TE(:));";
metrics = ["mean(maxk(R.mqw.emission.spontaneous_TE(:), 3))", ...
           "-abs(mean(R.mqw.emission.wavelength(R.peakI(1:3)))*1e9-980)", ...
           "mean(R.mqw.emission.spontaneous_TE(find(R.mqw.emission.wavelength >= 1.02e-6, 3)))", ...
           "mean(R.mqw.emission.stimulated_TE(find(R.mqw.emission.wavelength >= 1.02e-6, 3)))"];
mLabels = ["Peak Rsp", ...
           "Peak Wavelength Offset from 980 [nm]", ...
           "Rsp at 980 nm", ...
           "Rst at 980 nm"];

% Data reduction
rejectData = "0";

% Optional plotting options
contour=10;
contourlim=nan(2,numel(params)+numel(metrics));
%     contourlim(:,params=="wWG")=[1; 2];
%     contourlim(:,params=="etchDepth")=[0.2; 0.6];
%     contourlim(:,params=="d")=[0.4; 1.2];
%     contourlim(:,params=="d2")=[0.4; 1.2];
nominal=nan(size(contourlim(1,:)));
    nominal(params=="R.cden")=2;
    nominal(params=="R.Nqw")=3;
    nominal(params=="R.tQW*1e3") =4;
    nominal(params=="R.tQWB*1e3")=4;
    nominal(params=="R.xQW") =0.35;
% nominalvar=nominal * 0.2;   % 20% variation
nominalvar=NaN*nominal; % No nominal variation


%% Call main plot function
fprintf("Plotting '%s'...\n", sweepName);
run(baseScript);
