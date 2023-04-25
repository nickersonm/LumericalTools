%% Load, process, and plot simulation result data
% Michael Nickerson 2021-08-02

clear; close('all');


%% Simulation-specific definitions
% Load definitions
def_LiNbO3_x_WG;

%% Set customizations
resExts = ["_FDE.mat", "_CHARGE.mat"];
dualMode = 1;
sweepName = "LiNbO3_x_mod_wWG";
% sweepName = "LiNbO3_x_mod_fullsweep_1";


%% Plot parameters
noPlotParams = ["R.padDepth", "diff(R.simY)", "R.maxModes", ...
                "TM Modal Gain [dB/cm]", "TE Modal Gain [dB/cm]", ...
                "TM Phase Modulation [rad/mm]", "TM RAM [dB/mm]", ...
                "Desired Output Overlap", "High Isolation & Overlap", ...
                "Modal Isolation [dB/cm]", "TM Modal Isolation [dB/cm]", ...
                "Effective Index", "Fundamental Modal Gain [dB/cm]", ...
                "Fundamental Mode Number"];
noPlotTogether = ["Fundamental TE Gain [dB/cm]", "Modal Isolation [dB/cm]";
                  "Fundamental TE Gain [dB/cm]", "TE RAM [dB/mm]";
                  "Fundamental TE Gain [dB/cm]", "TE Phase Modulation [rad/mm]";
                  "Fundamental TE Gain [dB/cm]", "Effective Index";
                  "TE RAM [dB/mm]", "Modal Isolation [dB/cm]";
                  "TE RAM [dB/mm]", "TE Phase Modulation [rad/mm]";
                  "Modal Isolation [dB/cm]", "TE Phase Modulation [rad/mm]";
                  "Effective Index", "TE RAM [dB/mm]";
                  "Effective Index", "Modal Isolation [dB/cm]";
                  "Effective Index", "TE Phase Modulation [rad/mm]"];
savePlot = 0;
plot1D = 1;


%% Definitions
% Plotting script
baseScript = "sweepPlots_Base.m";
outDir = pwd + "/" + datestr(now, "yyyymmdd") + "/" + sweepName(1) + "/";

componentName = scriptName;

% Precomputation
preComp = "";

% Postcomputation
% postComp = ['if ~exist("iP", "var"); [~, iP] = sort( R.results.modeL + -1000*log10(R.results.Pout) ); end;', ...
% 'mode0 = getfield(R.simData, "mode"+string(R.results.modeN(iP(1)))); mode0.E = sum(mode0.E, [1,2]); mode0.y = 0;', ...
% 'activeRegion = struct("x", mode0.x, "y", 0);', ...
% 'activeRegion.z = 1e-6*unique(cell2mat(arrayfun(@(i) linspace(R.layerProps(i,1), R.layerProps(i,2), 50), 1:size(R.layerProps,1), "UniformOutput", false))'');', ...
% 'activeRegion.E = zeros(1, 1, numel(activeRegion.z), 3);', ...
% 'layerMQW = real(R.layerProps( imag(R.layerProps(:,3)) < 0, 1:2));', ...
% 'activeRegion.E(:, :, layerMQW(2) <= 1e6*activeRegion.z & 1e6*activeRegion.z <= layerMQW(1), 2) = 1;'];

% Files to load
resFiles = [];
for sweep = sweepName
    resFiles = [resFiles; dir("./sweeps/" + sweep + "/" + scriptName+"*.mat")];
end
resFiles = unique(regexprep(string({resFiles.folder}') + "/" + string({resFiles.name}'), "_[a-zA-Z]+\.mat", ""));

% Parameters to plot; needs to evaluate to doubles
params = ["double(R.lActive > 1)", "R.lambda", "R.wWG", "R.etchDepth", "R.padDepth", "diff(R.simY)", "R.maxModes", "R.dataRes", ...
          "R.sim2D", "R.sim1D", "double(strcmp(R.etchMat, 'SiO2'))", "R.outField.pol", "R.wgBR", ...
          "R.d", "R.d2"];
pLabels = ["Active", "Wavelength", "WG Width", "Etch Depth", "Pad Depth", "simY", "# Modes", "Data Resolution", ...
           "2D", "1D", "SiO2 Clad", "Polarization", "Bend Radius", ...
           "d", "d2"];

% Metrics
metrics = ["R.results.modeN(iP(1))", ...
           "-R.results.lossTE(iP(1)) - 1e3*(R.results.Pout(iP(1))<0.05)", ...
           "min([R.results.lossTE(iTE(iTE ~= iP(1))) - R.results.lossTE(iP(1))])*(R.results.Pout(iP(1))>0.01)", ...
           "min([R.results.lossTM(iTM(iTM ~= iP(1))) - R.results.lossTE(iP(1))])*(R.results.Pout(iP(1))>0.01)", ...
           "min([R.results.modeL(iP(iP ~= iP(1))) - R.results.modeL(iP(1))])*(R.results.Pout(iP(1))>0.01)", ...
           "R.results.Pout(iP(1))", ...
           "min([R.results.lossTE(iTE(iTE ~= iP(1))) - R.results.lossTE(iP(1)); 100])*R.results.Pout(iP(1))", ...
           "abs(R.results.modeNeff(iP(1)))"];
mLabels = ["Fundamental Mode Number", ...
           "Fundamental TE Gain [dB/cm]", ...
           "TE Modal Isolation [dB/cm]", ...
           "TM Modal Isolation [dB/cm]", ...
           "Modal Isolation [dB/cm]", ...
           "Desired Output Overlap", ...
           "High Isolation & Overlap", ...
           "Effective Index"];

% Data reduction
rejectData = "0";

% Optional plotting options
contour=10;
contourlim=nan(2,numel(params)+numel(metrics));
%     contourlim(:,params=="wWG")=[0.5; 2];
nominal=nan(size(contourlim(1,:)));
    nominal(params=="R.wWG")=1.5;
    nominal(params=="R.etchDepth")=0.4;
% nominalvar=nominal * 0.2;   % 20% variation
nominalvar=NaN*nominal; % No nominal variation


%% Call main plot function
fprintf("Plotting '%s'...\n", sweepName);
run(baseScript);
