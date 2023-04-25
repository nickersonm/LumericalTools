%% Load, process, and plot simulation result data
% Michael Nickerson 2021-08-02

clear; close('all');


%% Simulation-specific definitions
% Load definitions
def_GaAs_SSC_AR8;

% Non-modulating
dualMode = 0;
resExts = "_varFDTD.mat";
sweepName = "AR8_passive_SSC_deep";
% sweepName = "AR8_passive_deep_aFacet";

% resExts = "_FDTD.mat";
% sweepName = "AR8_passive_SSC_deep_FDTD";
% sweepName = "AR8_passive_deep_aFacet_FDTD";

% Plot parameters
noPlotParams = ["simY", "SSC2 Length"];
noPlotTogether = ["Pout [dB]", "Transmitted Fraction [dB]"];
savePlot = 0;
plot1D = 1;


%% Definitions
% Plotting script
baseScript = "../sweepPlots_Base_20220929.m";
outDir = pwd + "/" + datestr(now, "yyyymmdd") + "/" + sweepName(1) + "/";

componentName = scriptName;

% Precomputation
preComp = "if ~isfield(R, 'aFacet'); R.aFacet=0; end";

% Files to load
resFiles = [];
for sweep = sweepName
    resFiles = [resFiles; dir("./sweeps/" + sweep + "/" + scriptName+"*.mat")];
end
resFiles = unique(regexprep(string({resFiles.folder}') + "/" + string({resFiles.name}'), "_[a-zA-Z]+\.mat", ""));

% Parameters to plot; needs to evaluate to doubles
params = ["double(R.lActive > 1)", "R.lambda", "R.wWG1", "R.wWG2", "R.etch1", "R.etch2", "R.padDepth", "diff(R.simY)", "R.maxModes", "R.dataRes", ...
          "R.sim2D", "R.sim1D", "double(strcmp(R.etchMat, 'SiO2'))", "R.inPort{1}.pol", "R.outField.pol", "R.wgBR", "R.lWG", ...
          "R.wSSC1", "R.wSSC2", "R.dSSC1", "R.dSSC2", "R.lSSC1", "R.lSSC2", "R.lStrt", "R.lFS", "R.Q", "R.aFacet"];
pLabels = ["Active", "Wavelength", "WG Width 1", "WG Width 2", "Etch 1 Depth", "Etch 2 Depth", "Pad Depth", "simY", "# Modes", "Data Resolution", ...
           "2D", "1D", "SiO2 Clad", "Input Polarization", "Output Polarization", "Bend Radius", "WG Length", ...
           "SSC1 Width", "SSC2 Width", "SSC1 Etch Depth", "SSC2 Etch Depth", "SSC1 Length", "SSC2 Length", "SSC Straight", "SSC FS Length", "SSC Curvature", "Facet Angle"];

% Metrics
metrics = ["10*log10(R.results.Pout)", "10*log10(R.results.Ptr)", "10*log10(R.results.P11)"];
mLabels = ["Pout [dB]", "Transmitted Fraction [dB]", "Pin [dB]"];

% Data reduction
rejectData = "R.sim2D == 1";

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
