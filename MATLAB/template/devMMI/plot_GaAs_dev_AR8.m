%% Load, process, and plot simulation result data
% Michael Nickerson 2021-08-02

clear; close('all');


%% Simulation-specific definitions
% Load definitions
def_GaAs_MMI_AR8;

% Non-modulating
dualMode = 0;
resExts = "_varFDTD.mat";
sweepName = "AR8_passive_MMI_1x1_deep_dl";
% sweepName = "AR8_passive_MMI_1x2_deep_dl";
% sweepName = "AR8_passive_MMI_1x3_deep_dl";
% sweepName = "AR8_passive_MMI_1x4_deep_dl";
% sweepName = "AR8_passive_MMI_1x2_deep_varFDTD_lambda";
% sweepName = "AR8_passive_MMI_1x4_deep_varFDTD_lambda";


% Plot parameters
noPlotParams = ["simY", "MMI Length", "MMI Width", "Transmitted Fraction [dB]"];
noPlotTogether = ["Pout [dB]", "P12 [dB]"];
savePlot = 0;
plot1D = 0;


%% Definitions
% Plotting script
baseScript = "sweepPlots_Base.m";
outDir = pwd + "/" + datestr(now, "yyyymmdd") + "/" + sweepName(1) + "/";

componentName = scriptName;

% Precomputation
preComp = "R.N = R.N + 20*(R.dyIn ~= 0);";

% Files to load
resFiles = [];
for sweep = sweepName
    resFiles = [resFiles; dir("./sweeps/" + sweep + "/" + scriptName+"*.mat")];
end
resFiles = unique(regexprep(string({resFiles.folder}') + "/" + string({resFiles.name}'), "_[a-zA-Z]+\.mat", ""));

% Parameters to plot; needs to evaluate to doubles
params = ["double(R.lActive > 1)", "R.lambda", "R.wWG1", "R.wWG2", "R.etch1", "R.etch2", "R.padDepth", "diff(R.simY)", "R.maxModes", "R.dataRes", ...
          "R.sim2D", "R.sim1D", "double(strcmp(R.etchMat, 'SiO2'))", "R.inPort{1}.pol", "R.outField.pol", "R.wgBR", "R.lWG", ...
          "R.wMMI", "R.dwMMI", "R.lMMI", "R.dlMMI", "R.N", "R.wSpace", "R.lTaperIn", "R.lTaperOut", "R.dTaper"];
pLabels = ["Active", "Wavelength", "WG Width 1", "WG Width 2", "Etch 1 Depth", "Etch 2 Depth", "Pad Depth", "simY", "# Modes", "Data Resolution", ...
           "2D", "1D", "SiO2 Clad", "Input Polarization", "Output Polarization", "Bend Radius", "WG Length", ...
           "MMI Width", "MMI δWidth", "MMI Length", "MMI δLength", "N Outputs", "MMI Output Space", "MMI Input Taper", "MMI Output Taper", "MMI Output Space Between Tapers"];

% Metrics
metrics = ["10*log10(R.results.Pout)", "10*log10(R.results.P12)", "10*log10(R.results.Ptr)"];
mLabels = ["Pout [dB]", "P12 [dB]", "Transmitted Fraction [dB]"];

% Data reduction
rejectData = "0";

% Optional plotting options
contour=10;
contourlim=nan(2,numel(params)+numel(metrics));
%     contourlim(:,params=="wWG1")=[1; 2];
nominal=nan(size(contourlim(1,:)));
    nominal(params=="R.wWG1")=2.0;
    nominal(params=="R.etch1")=2.5;
% nominalvar=nominal * 0.2;   % 20% variation
nominalvar=NaN*nominal; % No nominal variation


%% Call main plot function
fprintf("Plotting '%s'...\n", sweepName);
run(baseScript);
