%% Quickly load and plot Lumerical sweep results
% Michael Nickerson 2022-09-29, updated 2023-04-10


%% Definitions
% REQUIRES sweepPlots_componentName to define variables:
%   componentName
%   outDir
%   resFiles
%   resExts
%   params
%   metrics
% OPTIONAL variables:
%   rejectData
%   pLabels
%   mLabels
%   preComp
%   postComp
%   noPlotParams: will not plot these parameters at all
%   noPlotTogether: will not simultaneously plot items in a row
%   contour: will plot contours with this many grid points, instead of scatterplot correlations
%   contourlim=[paramvals.*[max;min]]: will adjust contour plot axes
%   nominal=[paramval]: will place nominal point on contour plots
%   nominalvar=[paramvals]: variation box of nominal parameters
%   savePlot: save plots?


%% Process expected vairables
if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist('dualMode', 'var'); dualMode = 1; end
if ~exist('contourSize', 'var'); contourSize = [1000, 700]; end
if ~exist('savePlot', 'var'); savePlot = 1; end
if ~exist('plot1D', 'var'); plot1D = 1; end
if ~exist('preComp', 'var'); preComp = ""; end
if ~exist('postComp', 'var'); postComp = ""; end
if ~exist('rejectData', 'var'); rejectData = "0"; end

% Label
if ~exist('pLabels', 'var');  pLabels = params;   end
if ~exist('mLabels', 'var');  mLabels = metrics;   end
if ~exist('noPlotParams', 'var'); noPlotParams = ""; end
if ~exist('noPlotTogether', 'var'); noPlotTogether = ["",""]; end


%% Load data files
% Merge params and metrics
[params, iU] = unique([params, metrics], "stable");
pLabels = [pLabels, mLabels]; pLabels = pLabels(iU);
resData = NaN(0, numel(params));

% Load specific parameters from each file
fprintf("Loading files: "); lastOut = '';
for i = 1:numel(resFiles)
    lastOut = utilDisp(sprintf('%i/%i', i, numel(resFiles)), lastOut);
    
    pData = loadDataFile(resFiles(i), resExts, params, rejectData, preComp, postComp, dualMode);
    resData = [resData; pData];
end
utilDisp(sprintf("done.\n\n"), lastOut);

assert(size(resData,1) >= 1, sprintf('No valid data found for "%s"!', componentName));

% Clear extraneous variables
clearvars -except resFiles resExts resData componentName outDir params fieldData ...
    noPlotParams metrics rejectData preComp postComp pLabels mLabels contour contourlim ...
    nominal nominalvar contourSize dualMode savePlot noPlotTogether plot1D


%% Clean data
% Remove duplicate rows
[resData, iU] = unique(resData, 'rows');
resFiles = resFiles(iU);

% Remove fields without variation
iR = round(std(resData, [], 1, 'omitnan'), 5) == 0 | ismember(params, noPlotParams) | ismember(pLabels, noPlotParams);
if ~isempty(iR) && any(iR)
    mLabels(ismember(metrics, params(iR))) = [];
    metrics(ismember(metrics, params(iR))) = [];
    pLabels(iR) = [];
    params(iR) = [];
    resData(:, iR) = [];
    contourlim(:,iR) = [];
    nominal(iR) = [];
    nominalvar(iR) = [];
end

% Remove invalid rows
iR = any(isnan(resData), 2);
resData = resData(~iR,:);
resFiles = resFiles(~iR);

% Copy metrics into separate variable
mData = resData(:, (end-numel(metrics)+1):end);
if all(isempty(mData))
    fprintf("\nNo nonconstant metrics from '%s' to plot!\n", componentName);
    return;
end


%% Plot extracted data
% Iterate parameters, only plot ones with variation
plPairs = ["" ""];
if plot1D
    if size(params,2) > 3; input('Press Enter to continue...'); end
    
    for pX = params
        pI = find(pX == params, 1);
        dataX = resData(:, pI);
        
        % Iterate metrics
        for mI = 1:numel(metrics)
            % Skip if same as current x-axis or in noPlotTogether
            if pX == metrics(mI) ...
                    || any(all([pX == plPairs(:,1), metrics(mI) == plPairs(:,2)], 2)) ...
                    || any(all(ismember(string(noPlotTogether), [pX, metrics(mI)]),2)) ...
                    || any(all(ismember(string(noPlotTogether), [pLabels(pI), mLabels(mI)]),2))
                continue;
            end
            plPairs = [plPairs; metrics(mI), pX];
            
            % Plot
            plTitle = sprintf("%s\n%s vs %s", strrep(componentName, "_", "\_"), mLabels(mI), pLabels(pI));
            h = plotStandard2D([dataX, mData(:, mI)], 'style', 'x', 'MarkerSize', 10, ...
                               'ylabel', mLabels(mI), 'xlabel', pLabels(pI), ...
                               'axfs', 16, 'axfw', 'Bold', ...
                               'title', plTitle, ...
                               'fig', pI*numel(metrics) + mI, 'size', [1000, 700]);
            if savePlot
                print(outDir + "Sweep - " + matlab.lang.makeValidName(plTitle) + ".png", '-dpng');
            end
        end
    end
end


%% Plot contour plots with remaining parameter pairs
if numel(params) > 1
    iPairs = nchoosek(1:length(params), 2);
    if size(iPairs,1) > 5; input('Press Enter to continue...'); end
    
    for i = 1:size(iPairs,1)
        for mI = 1:numel(metrics)
            % Skip if x or y is same as z-axis or in noPlotTogether
            if any(params(iPairs(i,:)) == metrics(mI)) ...
                    || any(all(ismember(string(noPlotTogether), [params(iPairs(i,:)), metrics(mI)]),2)) ...
                    || any(all(ismember(string(noPlotTogether), [pLabels(iPairs(i,:)), mLabels(mI)]),2))
                continue;
            end
            
            h = figureSize((numel(params)+1)*numel(metrics) + i*numel(metrics) + mI, contourSize);
            clf(h);
            
            pl1D = 0;
            if numel(unique(resData(:, iPairs(i,1)))) <= 4 || numel(unique(resData(:, iPairs(i,2)))) <= 4
                % Make a line plot instead
                pl1D = 1;
                iP = 1 + (numel(unique(resData(:, iPairs(i,1)))) > numel(unique(resData(:, iPairs(i,2)))));
                niP = setdiff([1 2], iP);
                uP = unique(resData(:, iPairs(i,iP)));
                
                ax=[]; axL = [];
                marker = ['o', 'x', '.', '+', 'v'];
                for j = 1:numel(uP)
                    iS = resData(:, iPairs(i, iP)) == uP(j);
                    ax = [ax, plot(resData(iS, iPairs(i, niP)), mData(iS, mI), marker(j), 'MarkerSize', 10, 'LineWidth', 2)];
                    axL = [axL, sprintf("%s = %.4g", pLabels(iPairs(i, iP)), uP(j))];
                    hold on;
                end
                hold off;
                xlabel(pLabels(iPairs(i,niP)), 'FontSize', 16, 'FontName', 'Consolas', 'FontWeight', 'Bold');
                ylabel(mLabels(mI), 'FontSize', 16, 'FontName', 'Consolas', 'FontWeight', 'Bold');
            elseif exist('contour', 'var') && (contour > 0)
                % Prepare data
                if contour == 1
                    N = ceil( min( numel(unique(resData(:, iPairs(i,1)))), ...
                                   numel(unique(resData(:, iPairs(i,2))))) / 4);
                else
                    N = contour;
                end
                if N<2; continue; end
                [hg, vg, dg] = smoothGrid(real(resData(:, iPairs(i,1))), ...
                                          real(resData(:, iPairs(i,2))), ...
                                          real(mData(:, mI)), N, @max);
                
                contourf(hg, vg, dg'); grid on;
                
                hold on; scatter(resData(:, iPairs(i,1)), resData(:, iPairs(i,2)), 'filled'); hold off;
                
                if exist('contourlim', 'var')
                    if ~all(isnan(contourlim(:,iPairs(i,1))))
                        xlim( contourlim(:,iPairs(i,1)) );
                    end
                    if ~all(isnan(contourlim(:,iPairs(i,2))))
                        ylim( contourlim(:,iPairs(i,2)) );
                    end
                end
            else
                % Scatterplot
                scatter(resData(:, iPairs(i,1)), real(resData(:, iPairs(i,2))), 300, mData(:, mI), 'filled');
            end
            a = h.CurrentAxes;
            grid on; axis manual;
            if ~pl1D
                xlabel(pLabels(iPairs(i,1)), 'FontSize', 16, 'FontName', 'Consolas', 'FontWeight', 'Bold');
                ylabel(pLabels(iPairs(i,2)), 'FontSize', 16, 'FontName', 'Consolas', 'FontWeight', 'Bold');
                ylabel(colorbar, mLabels(mI), 'FontSize', 16, 'FontName', 'Consolas', 'FontWeight', 'Bold');
            end
            
            % Plot nominal parameters
            if exist('nominal', 'var') && ~any(isnan(nominal(iPairs(i,:))))
                hold(a, 'on');
                pos = nominal(iPairs(i,:));
                if ~pl1D
                    s = scatter(a, pos(1), pos(2), 100, 'black', 'p', ...
                                'MarkerFaceColor', 'black', 'LineWidth', 5);
                else
                    s = plot(a, pos(niP)*[1;1], [-1e6;1e6], 'k:', 'LineWidth', 2);
                end
                
                % Plot nominal variation
                if exist('nominalvar', 'var') && ~any(isnan(nominalvar(iPairs(i,:))))
                    pvar = [nominalvar(iPairs(i,1)), nominalvar(iPairs(i,2))];
                    r = rectangle(a, 'Position', [pos-pvar, pvar*2], ...
                                  'EdgeColor', 'black', 'LineWidth', 3, 'LineStyle', ':');
                end
                hold(a, 'off');
                
                if exist('ax', 'var') && ~isempty(ax)
                    ax = [ax, s]; axL = [axL, "Nominal Value"];
                end
            end
            
            if pl1D
                legend(ax, axL, "FontSize", 14, 'Location','south');
            end

            a.Units = "pixels";
            % Title
            plTitle = titlewrap(sprintf("%s\n%s\n%s vs %s", strrep(componentName, "_", "\_"), mLabels(mI), pLabels(iPairs(i,1)), pLabels(iPairs(i,2))), 120, "vs");
            figureTitle(h, plTitle, 0.10 + 0.02*numel(strfind(plTitle, newline)), "FontSize", 16); drawnow;
            figureSize(h, contourSize + [0, 30*numel(strfind(plTitle, newline))]); drawnow;
            if savePlot
                print(outDir + "Correlation - " + matlab.lang.makeValidName(plTitle) + ".png", '-dpng');
            end
        end
        % Avoid replotting pair on different axis
        noPlotTogether = [noPlotTogether; params(iPairs(i,:))];
%                           [params(iPairs(i,1)), metrics(mI)];
%                           [params(iPairs(i,2)), metrics(mI)]];
    end
end
drawnow;


%% Now load and plot the top few planar plots
[~, iBest] = maxk(mData, 3); iBest = unique(iBest);
iBest = unique(iBest(all(~isnan(mData(iBest(:), :)), 2)));

if numel(iBest) > 0
    input('Press Enter to continue...');
end

for i = iBest'
    % Generate labels
    plTitle = strrep(componentName, "_", "\_") + ": " + sprintf("%s = %s, ", [pLabels; string(num2str(resData(i,:)', "%.4g"))']);
    plTitle = strcrunch(extractBefore(plTitle, strlength(plTitle)-1));
    % Plot titles get very long, so just hash for unique plot filenames
    plSave = outDir + "Fields - " + componentName + " - " + string(DataHash(plTitle)) + ".png";
    
    % Plot and save
    [~, R] = loadDataFile(resFiles(i), resExts, params, rejectData, preComp, postComp, dualMode);
    h = plotResultYZ(R, ...
                    'title', plTitle, ...
                    'handle', 100 + i);
    if savePlot > 0; print(plSave, '-dpng'); end
end


%% Helper functions
% Remove any double spaces
function s = strcrunch(s)
    ss = s;    
    while true
        s = replace(s, "  ", " ");
        if strlength(s) == strlength(ss); break; end
        ss = s;
    end
end

% Add metric
function addmetric(m, ml)
    if ~any(evalin('base', 'metrics') == m) && ~evalin('base', "exist('iBest', 'var')")
        evalin('base', "params  = [params, """+m+"""];");
        evalin('base', "pLabels = [pLabels, """+ml+"""];");
        evalin('base', "metrics = [metrics, """+m+"""];");
        evalin('base', "mLabels = [mLabels, """+ml+"""];");
        evalin('base', "resData = [resData, NaN(size(resData(:,1)))];");
        evalin('base', "contourlim = [contourlim, NaN(size(contourlim(:,1)))];");
        evalin('base', "nominal = [nominal, NaN(size(nominal(:,1)))];");
        evalin('base', "nominalvar = [nominalvar, NaN(size(nominalvar(:,1)))];");
        
        evalin('caller', "params  = [params, """+m+"""];");
    end
end

% Display helper
function out = utilDisp(out, varargin)
    if numel(varargin) > 0; lastout = varargin{1}; else; lastout = ''; end
    
    fprintf(repmat('\b', 1, numel(sprintf(lastout))));
    fprintf(out);
end

% Field normalization
function N = fieldNorm(f)
    f.E = sum(abs(f.E).^2, 5);
    if numel(f.z) > 1; f.E = trapz(f.z, f.E, 3); end
    if numel(f.y) > 1; f.E = trapz(f.y, f.E, 2); end
    if numel(f.z) > 1; f.E = trapz(f.x, f.E, 1); end
    N = squeeze(f.E);
end

% Load data
function [pData, R] = loadDataFile(resFile, resExts, params, rejectData, preComp, postComp, dualMode)
    pData = NaN(size(params));
    
    % Load all associated files
    nResult = 0; R = struct;
    for extF = resExts
        if isfile(resFile + extF)
            R = appendstruct(R, load(resFile + extF));
            nResult = nResult + 1;
        end
    end
    
    if (nResult < 2 && dualMode == 1) || (nResult < 1 && dualMode == 0)
        fprintf("%i results found for '%s'; skipping\n", nResult, resFile);
        return;
    end
    
    % Record entry data if not rejected
    if eval(rejectData) == 0
        % User-specified precomputation
        if ~isempty(preComp); eval(preComp); end
        
        % Built-in metrics
%         if isfield(R, "simData") && isfield(R.simData, "outputField") && isfield(R.simData, 'inputField')
%             R.results.Ptr = fieldNorm(R.simData.outputField) / (fieldNorm(R.simData.outputField) + fieldNorm(R.simData.inputField));
%         end
        
        % Modal results for FDE
        if isfield(R, "results") && isfield(R.results, "modeN")
            % Analytical model results with CHARGE data
            if isfield(R, "simData") && isfield(R.simData, "CHARGE") && isfield(R, "lambda") && ...
                    isfield(R.simData, "mode"+R.results.modeN(1)) && isfield(R.simData, "index")
                % Force Ppad as the name in case different name is used
                fn=string(fieldnames(R.simData)); R.simData.Ppad = R.simData.(fn(contains(fn, 'Ppad')));
                
                addmetric("R.results.dn(R.results.modeTE)", "TE Phase Modulation [rad/mm]");
                addmetric("R.results.dn(R.results.modeTM)", "TM Phase Modulation [rad/mm]");
                addmetric("R.results.da(R.results.modeTE)", "TE RAM [dB/mm]");
                addmetric("R.results.da(R.results.modeTM)", "TM RAM [dB/mm]");
                addmetric("R.results.V", "Bias [V]");
                EE = appendstruct(R.simData.CHARGE, struct("Vbias", R.simData.Ppad.V));
                index = cat(3, R.simData.index.nx, R.simData.index.ny, R.simData.index.nz);
                for j = 1:numel(R.results.modeN)
                    [dn, alpha, V] = analyticalModelGaAs(R.simData.("mode"+R.results.modeN(j)), ...
                                                      EE, 'lambda', R.lambda, 'index', index);
                    R.results.V = V(find(abs(V)==max(abs(V)),1));
                    R.results.dn(j,1) = (max(dn) - min(dn))*2*pi/(R.lambda*1e-3);
                    R.results.da(j,1) = (max(alpha) - min(alpha))*log10(exp(1)); % cm^-1 -> dB/mm
                    % Update modal loss
                    R.results.modeL(j) = R.results.modeL(j) + ...
                                         (alpha(find(V==R.results.V,1)) - alpha(find(V==0,1)))*1e3*log10(exp(1)); % cm^-1 -> dB/m
                end
            end
            
            % Convert modal gain to dB/cm
            R.results.modeL = R.results.modeL/1e2;
            
            % Remove irrelevant modes
            iR = abs(R.results.modeL) < 1e5;
            R.results.modeL = R.results.modeL(iR);
            R.results.modeN = R.results.modeN(iR);
            R.results.modeNeff = R.results.modeNeff(iR);
            R.results.modePol = R.results.modePol(iR);
            R.results.Pout = R.results.Pout(iR);
            
            % Recalculate desired overlap if gaussian, centering at mode peak for each mode
            if isfield(R.outField, 'mfd') && R.outField.mfd(1) > 0
                % Recompute output field centered at zero
                R.outField.y = R.outField.y(:) - mean(R.outField.y, "all");
                R.outField.z = R.outField.z(:) - mean(R.outField.z, "all");
                R.outField.power = normpdf(R.outField.y, 0, R.outField.mfd(1)/2 ) ...
                                 * normpdf(R.outField.z, 0, R.outField.mfd(1)/2 )';
                R.outField.E = zeros(numel(R.outField.x), numel(R.outField.y), numel(R.outField.z), 3);
                R.outField.E(:,:,:,2) = (1-R.outField.pol) * R.outField.power .^ 0.5;
                R.outField.E(:,:,:,3) = R.outField.pol * R.outField.power .^ 0.5;
                R.outField.E = R.outField.E ./ max(abs(R.outField.E), [], "all");
            end
            
            % Compute output overlaps, M^2 values, and effective mode area
            tmpField = R.outField;
            for i = 1:numel(R.results.modeN)
                mode = R.simData.("mode"+num2str(R.results.modeN(i)));
                
                % Shift output field center to mode peak
                [~, zI] = sort(-sum(abs(mode.E).^2, [1,2,4]));
                tmpField.z = R.outField.z + mode.z(zI(1));
                
                % Compute overlap
                [~, R.results.Pout(i)] = fieldOverlap(mode, tmpField);

                % Compute M^2
                [R.results.Msq(i), R.results.MsqY(i), R.results.MsqZ(i)] = ...
                    fieldMsq(mode, R.lambda);

                % Compute mode area
                R.results.A(i) = fieldModeArea(mode)*1e12;
            end
            
            addmetric("R.results.Msq(R.results.modeP)", "Fundamental Mode M^2 value");
            addmetric("R.results.MsqY(R.results.modeP)", "Fundamental Mode M_y^2 value");
            addmetric("R.results.MsqZ(R.results.modeP)", "Fundamental Mode M_z^2 value");
            addmetric("R.results.A(R.results.modeP)", "Fundamental Mode Effective Mode Area [µm^2]");
            
            % Extend if only one mode; some metrics rely on 2nd mode offset
            if numel(R.results.modeL) < 2
                R.results.modeL(2) = inf;
                R.results.modePol(2) = 0.5;
            end
            
            % Calculate effective TE and TM modal losses
            R.results.lossTE = R.results.modeL + -10*log10(abs(1-R.results.modePol) );
            R.results.lossTM = R.results.modeL + -10*log10(R.results.modePol);
            R.results.lossPout = R.results.modeL + -10*log10(R.results.Pout);
            
            % Add TE and TM metrics
            [~, iTE] = sort( R.results.lossTE ); R.results.modeTE = iTE(1);
            [~, iTM] = sort( R.results.lossTM ); R.results.modeTM = iTM(1);
            [~, iP]  = sort( R.results.lossPout + -100*log10(R.results.Pout) ); R.results.modeP = iP(1);
            
            addmetric("-R.results.modeL(R.results.modeP)", "Fundamental Modal Gain [dB/cm]");
            addmetric("-R.results.lossTE(R.results.modeTE)", "TE Modal Gain [dB/cm]");
            addmetric("-R.results.lossTM(R.results.modeTM)", "TM Modal Gain [dB/cm]");
        end
        
        % User-specified postcomputation
        if ~isempty(postComp); eval(postComp); end
        
        % User-specified parameters and metrics
        pData = arrayfun(@(m) evalin('caller', m), params);
    else
        R = [];
    end
end
