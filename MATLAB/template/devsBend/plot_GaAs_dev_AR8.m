%% Load, process, and plot simulation result data
% Michael Nickerson 2021-08-02

clear; close('all');


%% Simulation-specific definitions
% Load definitions
def_GaAs_sBend_AR8;

dualMode = 0;
resExts = "_varFDTD.mat";
sweepName = "AR8_dev_Sbend_varFDTD_1";
% sweepName = ["AR8_dev_Sbend_varFDTD_2", "AR8_dev_Sbend_varFDTD_1"];

% Plot parameters
noPlotParams = ["simY", "simX", "P12 [dB]"];
noPlotTogether = ["Pout [dB]", "P12 [dB]"];
savePlot = 0;
plot1D = 0;


%% Definitions
% Plotting script
baseScript = "sweepPlots_Base.m";
outDir = pwd + "/" + datestr(now, "yyyymmdd") + "/" + sweepName(1) + "/";

componentName = scriptName;

% Precomputation
% preComp = "R.outField.mfd(1) = 2e-6;";

% Files to load
resFiles = [];
for sweep = sweepName
    resFiles = [resFiles; dir("./sweeps/" + sweep + "/" + scriptName+"*.mat")];
end
resFiles = unique(regexprep(string({resFiles.folder}') + "/" + string({resFiles.name}'), "_[a-zA-Z]+\.mat", ""));

% Parameters to plot; needs to evaluate to doubles
params = ["double(R.lActive > 1)", "R.lambda", "R.wWG1", "R.wWG2", "R.etch1", "R.etch2", "R.padDepth", "diff(R.simY)", "diff(R.simX)", "R.maxModes", "R.dataRes", ...
          "R.sim2D", "R.sim1D", "double(strcmp(R.etchMat, 'SiO2'))", "R.inPort{1}.pol", "R.outField.pol", "R.wgBR", "R.lWG", ...
          "R.dY"];
pLabels = ["Active", "Wavelength", "WG Width 1", "WG Width 2", "Etch 1 Depth", "Etch 2 Depth", "Pad Depth", "simY", "simX", "# Modes", "Data Resolution", ...
           "2D", "1D", "SiO2 Clad", "Input Polarization", "Output Polarization", "Bend Radius", "WG Length", ...
           "Y-Offset"];

% Metrics
metrics = ["10*log10(R.results.Pout)", "10*log10(R.results.P12)", "10*log10(R.results.Ptr)"];
mLabels = ["Pout [dB]", "P12 [dB]", "Transmitted Fraction [dB]"];

% Data reduction
rejectData = "R.dY == 0";

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
