%% Load, process, and plot simulation result data
% Michael Nickerson 2021-08-02

clear; close('all');


%% Simulation-specific definitions
% Load definitions
def_GaAs_1D_AR8;


%% Set customizations
dualMode = 0;
resExts = ["_FDE.mat"];
sweepName = "AR8_active_tG";
% sweepName = "AR8_AP";


%% Plot parameters
noPlotParams = ["R.padDepth", "diff(R.simY)", "R.maxModes", ...
                "TM Modal Gain [dB/cm]", "TE Modal Gain [dB/cm]", ...
                "TM Phase Modulation [rad/mm]", "TM RAM [dB/mm]", ...
                "Desired Output Overlap", "High Isolation & Overlap", ...
                "Modal Isolation [dB/cm]", "TM Modal Isolation [dB/cm]", ...
                "Effective Index", "Fundamental Modal Gain [dB/cm]"];
noPlotTogether = ["Fundamental TE Gain [dB/cm]", "Modal Isolation [dB/cm]";
                  "Fundamental TE Gain [dB/cm]", "TE RAM [dB/mm]";
                  "Fundamental TE Gain [dB/cm]", "TE Phase Modulation [rad/mm]";
                  "Fundamental TE Gain [dB/cm]", "Effective Index";
                  "TE RAM [dB/mm]", "Modal Isolation [dB/cm]";
                  "TE RAM [dB/mm]", "TE Phase Modulation [rad/mm]";
                  "Modal Isolation [dB/cm]", "TE Phase Modulation [rad/mm]";
                  "Effective Index", "TE RAM [dB/mm]";
                  "Effective Index", "Modal Isolation [dB/cm]";
                  "Effective Index", "TE Phase Modulation [rad/mm]";
                  "\Gamma_{MQW}", "Effective Index";
                  "\Gamma_{MQW}", "Modal Isolation [dB/cm]";
                  "\Gamma_{MQW}", "Fundamental TE Gain [dB/cm]";
                  "\Gamma_{MQW}", "Fundamental Modal Gain [dB/cm]"];
savePlot = 0;
plot1D = 1;


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
resFiles = regexprep(string({resFiles.folder}') + "/" + string({resFiles.name}'), "_[a-zA-Z]+\.mat", "");

% Precomputation
preComp = "";

% Postcomputation
postComp = ['if ~exist("iP", "var"); [~, iP] = sort( R.results.modeL + -1000*log10(R.results.Pout) ); end;', ...
'mode0 = getfield(R.simData, "mode"+string(R.results.modeN(iP(1)))); mode0.E = sum(mode0.E, [1,2]); mode0.y = 0;', ...
'activeRegion = struct("x", mode0.x, "y", 0);', ...
'activeRegion.z = 1e-6*unique(cell2mat(arrayfun(@(i) linspace(R.layerProps(i,1), R.layerProps(i,2), 50), 1:size(R.layerProps,1), "UniformOutput", false))'');', ...
'activeRegion.E = zeros(1, 1, numel(activeRegion.z), 3);', ...
'if R.lActive>1; layerMQW = real(R.layerProps( imag(R.layerProps(:,3)) < 0, 1:2));', ...
'activeRegion.E(:, :, layerMQW(2) <= 1e6*activeRegion.z & 1e6*activeRegion.z <= layerMQW(1), 2) = 1; end;'];

% Files to load
resFiles = [];
for sweep = sweepName
    resFiles = [resFiles; dir("./sweeps/" + sweep + "/" + scriptName+"*.mat")];
end
resFiles = unique(regexprep(string({resFiles.folder}') + "/" + string({resFiles.name}'), "_[a-zA-Z]+\.mat", ""));

% Parameters to plot; needs to evaluate to doubles
params = ["double(R.lActive > 1)", "R.lambda", "R.wWG1", "R.wWG2", "R.etch1", "R.etch2", "R.padDepth", "diff(R.simY)", "R.maxModes", "R.dataRes", ...
          "R.sim2D", "R.sim1D", "double(strcmp(R.etchMat, 'SiO2'))", "R.outField.pol", "R.wgBR", ...
          "R.cden", "R.Nqw", "R.tQW*1e3", "R.tQWB*1e3", "R.xQW", "R.mqwStrain", ...
          "R.tUC", "R.xUC", ...
          "R.tG", ...
          "R.tLC", "R.xLC"];
pLabels = ["Active", "Wavelength", "WG Width 1", "WG Width 2", "Etch 1 Depth", "Etch 2 Depth", "Pad Depth", "simY", "# Modes", "Data Resolution", ...
           "2D", "1D", "SiO2 Clad", "Polarization", "Bend Radius", ...
           "Carrier Density [1e18 cm^-3]", "# QW", "QW Thickness [nm]", "Barrier Thickness [nm]", "In-fraction QW", "MQW Strain Calculated", ...
           "Upper Clad Thickness [µm]", "Upper Clad x-frac", ...
           "Guide Thickness [µm]", ...
           "Lower Clad Thickness [µm]", "Lower Clad x-frac"];

% Metrics
metrics = ["R.results.modeN(iP(1))", ...
           "-R.results.lossTE(iP(1)) - 1e3*(R.results.Pout(iP(1))<0.05)", ...
           "min([R.results.lossTE(iTE(iTE ~= iP(1))) - R.results.lossTE(iP(1))])*(R.results.Pout(iP(1))>0.01)", ...
           "min([R.results.lossTM(iTM(iTM ~= iP(1))) - R.results.lossTE(iP(1))])*(R.results.Pout(iP(1))>0.01)", ...
           "min([R.results.modeL(iP(iP ~= iP(1))) - R.results.modeL(iP(1))])*(R.results.Pout(iP(1))>0.01)", ...
           "R.results.Pout(iP(1))", ...
           "min([R.results.lossTE(iTE(iTE ~= iP(1))) - R.results.lossTE(iP(1)); 100])*R.results.Pout(iP(1))", ...
           "abs(R.results.modeNeff(iP(1)))", ...
           "real(fieldOverlap(mode0, activeRegion)) * (R.Nqw * R.tQW) / (R.Nqw * (R.tQW + R.tQWB) + R.tQWB)"];
mLabels = ["Fundamental Mode Number", ...
           "Fundamental TE Gain [dB/cm]", ...
           "TE Modal Isolation [dB/cm]", ...
           "TM Modal Isolation [dB/cm]", ...
           "Modal Isolation [dB/cm]", ...
           "Desired Output Overlap", ...
           "High Isolation & Overlap", ...
           "Effective Index", ...
           "\Gamma_{MQW}"];

% Data reduction
rejectData = "~isfield(R, 'tG')";

% Optional plotting options
contour=10;
contourlim=nan(2,numel(params)+numel(metrics));
%     contourlim(:,params=="wWG")=[1; 2];
nominal=nan(size(contourlim(1,:)));
    nominal(params=="R.tUC")=0.55;
    nominal(params=="R.xUC")=0.40;
    nominal(params=="R.tG") =3.45;
    nominal(params=="R.tLC")=0.90;
    nominal(params=="R.xLC")=0.45;
% nominalvar=nominal * 0.2;   % 20% variation
nominalvar=NaN*nominal; % No nominal variation


%% Call main plot function
fprintf("Plotting '%s'...\n", sweepName);
run(baseScript);
