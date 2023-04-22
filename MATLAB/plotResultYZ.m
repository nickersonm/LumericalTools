%% plotResultYZ.m  MN 2020-10-08
%   Formerly `plot2DResult.m`
%   Last updated 2022-09-29 for new Lumerical result format
% Helper function to plot standardized 2D Lumerical FDE/CHARGE/EME results produced via lum_analyze.lsf
% 
% Requirements:
%   .mat file produced by lum_analyze with FDE optical field and/or CHARGE
%       electric field
% 
% Usage: [plotHandle] = plotResultYZ(result, [options])
%   Returns:
%     plotHandle: handle to the plot
%
%   Parameters:
%     result: path to the result file(s) to load or structure from same; wildcards accepted
%
%     Options:
%       'indexdim', double: dim index colormap by this much (default 0.4)
%       'title', string: overall title for the plot (default none)
%       'save', filename: save png of the plot
%       'handle', h: use this figure handle to plot
%       'size', [x, y]: figure size (default [1300, 1600])
%       'margin', [x, y]: subplot margin (default [0.10, 0.05])
%       'mode', N: plot specified mode number, default best match
%       'dcpol', int: DC field index to plot [xyz]; default 3
%       'outfield', bool: plot outfield instead of secondary mode; default false
%
% TODO:
%   x Handle 1D

function plotHandle = plotResultYZ(result, varargin)
%% Defaults and magic numbers
indexDim = 0.5;
mode = 0;
saveFile = "";
plotHandle = [];
plotTitle = [];
plotSize = [1300, 600];
mgn = [0.14, 0.05];
dcFieldPol = 3;   % z-component of DC electric field is desired
outField = false;


%% Argument parsing
% Check required inputs
if isempty(result) || ( (~isstruct(result)) && (exist(result, 'file') ~= 2 && (numel(dir(result)) < 1) ) )
    error('Required input "result" is empty or does not correspond to any valid files.');
end

% Allow passing of cells of options
varargin = flatten(varargin);

% Accept a struct.option = value structure
if numel(varargin) > 0 && isstruct(varargin{1})
    paramStruct = varargin{1}; varargin(1) = [];
    varargin = [reshape([fieldnames(paramStruct) struct2cell(paramStruct)]', 1, []), varargin];
end

% Parameter parsing
while ~isempty(varargin)
    arg = lower(varargin{1}); varargin(1) = [];
    
    % Look for options
    switch lower(string(arg))
        case "transparency"
            indexDim = double(nextarg('transparency value'));
        case "title"
            plotTitle = string(nextarg('plot title'));
        case "save"
            saveFile = string(nextarg('save filename'));
        case {"handle", "fig", "h"}
            plotHandle = nextarg('plot handle');
            if ~isa(plotHandle, 'double') || ~isempty(ishandle(plotHandle)); plotHandle = []; end
        case "size"
            plotSize = double(nextarg('plot size'));
            if numel(plotSize) < 2
                plotSize = repmat(plotSize,1,2);
            end
        case "margin"
            mgn = double(nextarg('margin'));
        case "mode"
            mode = round(double(nextarg('selected mode')));
        case "dcpol"
            dcFieldPol = round(double(nextarg('DC field component')));
        case {"out", "outfield", "target"}
            outField = double(nextarg('plot output field')) > 0;
        otherwise
            if ~isempty(arg)
                warning('Unexpected option "%s", ignoring', num2str(arg));
            end
    end
end


%% Helper functions, if any
    % Get the next argument or error
    function arg = nextarg(strExpected)
        if isempty(strExpected); strExpected = ''; end
        if ~isempty(varargin)
            arg = varargin{1}; varargin(1) = [];
        else
            error('Expected next argument "%s", but no more arguments present!', strExpected);
        end
    end
    
    % Flatten a nested cell
    function flatCell = flatten(varargin)
        flatCell = {};
        for j=1:numel(varargin)
            if iscell(varargin{j})
                flatCell = [flatCell flatten(varargin{j}{:})];
            else
                flatCell = [flatCell varargin(j)];
            end
        end
        flatCell = flatCell( ~cellfun(@isempty, flatCell) );
    end
    
    % Effective ternary operator
    fi = @(varargin)varargin{length(varargin)-varargin{1}};


%% Load data
if isstruct(result)
    R = result;
else
    f = dir(result);
    
    % Load first result
    i = 1;
    R = load([f(i).folder, '\', f(i).name], '-mat');
    
    % Any further files; append to existing structure
    for i = 2:numel(f)
        R = appendstruct(R, load([f(i).folder, '\', f(i).name], '-mat'));
    end
end

if ~isfield(R, 'simData') || ~any(contains(string(fieldnames(R.simData)), "mode"))
    if isfield(R, 'mqw') && isfield(R.mqw, 'emission')
        % MQW result
        if isempty(plotHandle); plotHandle = ""; end
        plotHandle = plotMQW(R, 'title', plotTitle, 'handle', plotHandle, 'save', saveFile);
        return;
    else
        % Hand off to plotResult3D
        if isempty(plotHandle); plotHandle = ""; end
        plotHandle = plotResult3D(R, 'title', plotTitle, 'handle', plotHandle, 'save', saveFile);
        return;
    end
end
simData = R.simData;


%% Format results, assuming fields exist
n = []; ny = []; nz = [];
P = []; Py = []; Pz = []; alphaP = [];
E = []; Ey = []; Ez = []; alphaE = [];
pol = ["y", "z"]; Ppol = ""; Epol = "";

% FDE optical index
if isfield(simData, 'index')
    ny = real(simData.index.y); nz = real(simData.index.z);
    n = real((reshape(abs(simData.index.nx), numel(ny), [])' - 1).^0.25);
elseif isfield(simData, 'CHARGE')
    % Backup: CHARGE 'ID' - map to Cartesian and interpolate to reasonable density
    n = real(barycentricToCartesian(triangulation(simData.CHARGE.elem, simData.CHARGE.vtx), (1:size(simData.CHARGE.elem,1))', 0.5*ones(numel(simData.CHARGE.ID),3)));
    [ny, nz, n] = smoothGrid(n(:,2), n(:,3), ...
                             simData.CHARGE.ID(:), max(numel(simData.CHARGE.y), numel(simData.CHARGE.z)), @max);
    n = n';
end
n = n ./ max(n, [], 'all'); % Normalized for better color mapping

% If 1D, convert to real valued 2D for shaded background
if numel(ny) == 1
    ny = [0;1];
    n = repmat(reshape(real(simData.index.nx), 1, numel(nz)), 2, 1);
end


% FDE optical field
if isfield(R, 'results') && isfield(R.results, 'Pout')
    % Calculate effective TE modal loss and output-overlap loss
    if ~isfield(R.results, 'lossTE'); R.results.lossTE = R.results.modeL + -10*log10(abs(1-R.results.modePol) ); end
    if ~isfield(R.results, 'lossTM'); R.results.lossTM = R.results.modeL + -10*log10(R.results.modePol ); end
    if ~isfield(R.results, 'lossPout'); R.results.lossPout = R.results.modeL + -10*log10(R.results.Pout); end
    
    % Find most-desired mode
    if mode <= 0
        [~, modeI1] = sort( R.results.lossPout + -100*log10(R.results.Pout) );   % Strongly prefer overlap
        mode = R.results.modeN(modeI1(1));
    else
        modeI1 = find(R.results.modeN == mode, 1);
    end
    
    % Load mode data
    mode = simData.("mode"+num2str(mode));
    Py = mode.y; Pz = mode.z;
    P = squeeze(mode.E);
    if numel(size(P)) < 3
        % 1D data: insert dimension
        P = reshape(P, [numel(Py), numel(Pz), size(P,2)]);
    end
    P = abs(P(:,:,round(R.outField.pol+2))').^2;
    P = abs(smoothn(P, 2));
    P = P ./ max(P, [], 'all'); % Normalized for color mapping
    
    % Calculate transparency
    alphaP = isempty(n) + max(smoothn(P.^0.25, 5),0);
    
    title1 = sprintf("TE Mode, |E%s|^2 (%.1f dB/cm loss)", pol(round(R.outField.pol+1)), ...
                     R.results.modeL(modeI1(1)));
end
pl2D = ~any(size(P)==1);

% CHARGE electric field
fieldLabel = "";
if isfield(simData, 'CHARGE') && ~all(simData.Ppad.V == 0)
    % Find most reverse biased result
    [V, vI] = sort(simData.Ppad.V); vI = vI(1); V = V(1);
    title2 = sprintf("DC Electrical Field\n(%.2g V", V);    % Completed later
    Ey = simData.CHARGE.y; Ez = simData.CHARGE.z;
    E = squeeze(simData.CHARGE.E(:,:,:,dcFieldPol,vI))';
    
    % Check if second result; use closest-to-zero bias result
    [Va, vIa] = sort(abs(simData.Ppad.V)); vIa = vIa(1); Va = Va(1);
    if vIa(1) ~= vI(1)
        title2 = title2 + sprintf(" offset from %.2g V", Va);
        E = E - squeeze(simData.CHARGE.E(:,:,:,dcFieldPol,vIa))';
    end
    
    if any(size(P) == 1)
        % 1D optical data: reduce
        E = mean(E, find(size(P)==1));
    end
    
    E = abs(smoothn(E, 2));
    Emax = max(E, [], 'all');
    E = E ./ Emax; % Normalized for color mapping
    
    % Calculate transparency
    alphaE = max(smoothn(E.^0.5, 5),0);
    
    Epol = pol(dcFieldPol-1);
    title2 = title2 + ")" + sprintf(", |E%s| (max %.3g kV/cm^2)", Epol, Emax*1e-5);
    fieldLabel = ", Normalized Field";

elseif outField && isfield(R.outField, 'E')
    % Plot desired output field
    mode = R.outField;
    Ey = mode.y; Ez = mode.z;
    E = squeeze(mode.E);
    
    if numel(size(E)) < 3
        % 1D data: insert dimension
        E = reshape(E, [numel(Ey), numel(Ez), size(E,2)]);
    end
    E = abs(E(:,:,round(R.outField.pol+2))').^2;
    E = abs(smoothn(E, 2));
    E = E ./ max(E, [], 'all'); % Normalized for color mapping
    
    % Calculate transparency
    alphaE = isempty(n) + max(smoothn(E.^0.25, 5),0);
    
    title2 = "Target Output Field";
    if isfield(mode, 'mfd'); title2 = title2 + sprintf(" (%.1f µm MFD)", mode.mfd(1)*1e6); end
elseif numel(R.results.lossTE) > 1
    % If no CHARGE results, plot lowest-loss mode that is not primary mode
    % Lowest-loss TE mode
    [~, modeI2] = sort( R.results.lossTE + 1e6*(1:numel(modeI1) == modeI1(1))');
    mode = simData.("mode"+num2str(R.results.modeN(modeI2(1))));
    
    % Load mode data
    Ey = mode.y; Ez = mode.z;
    E = squeeze(mode.E);
    
    if numel(size(E)) < 3
        % 1D data: insert dimension
        E = reshape(E, [numel(Ey), numel(Ez), size(E,2)]);
    end
    E = abs(E(:,:,round(R.outField.pol+2))').^2;
    E = abs(smoothn(E, 2));
    E = E ./ max(E, [], 'all'); % Normalized for color mapping
    
    % Calculate transparency
    alphaE = isempty(n) + max(smoothn(E.^0.25, 5),0);
    
    title2 = sprintf("2nd TE Mode, |E%s|^2 (%.1f dB/cm loss)", pol(round(R.outField.pol+1)), ...
                     R.results.modeL(modeI2(1)));
else
    title2 = [];
end

% Get closest TM mode as well if only 1D plot
if ~pl2D && numel(R.results.lossTM) > 2 && ~isfield(simData, 'CHARGE')
    % Lowest-loss TM mode
    [~, modeI3] = sort( R.results.lossTM + 1e6*(1:numel(modeI1) == modeI1(1) | 1:numel(modeI1) == modeI2(1))');
    mode = simData.("mode"+num2str(R.results.modeN(modeI3(1))));
    
    % Load mode data
    E2y = mode.y; E2z = mode.z;
    E2 = squeeze(mode.E);
    % 1D data: insert dimension
    E2 = reshape(E2, [numel(E2y), numel(E2z), size(E2,2)]);
    
    E2 = sum(abs(E2).^2, 3);
    E2 = abs(smoothn(E2, 2));
    E2 = E2 ./ max(E2, [], 'all'); % Normalized for color mapping
    
    title3 = sprintf("TM Mode, |E|^2 (%.1f dB/cm loss)", R.results.modeL(modeI3(1)));
end



%% Plot
% Title and figure
plotShift = [20, 0];
if ~isempty(plotTitle)
    plotTitle = titlewrap(plotTitle, 80);
    % Increase size for larger title
    plotSize = plotSize + [0, 90*numel(strfind(plotTitle, newline))];
    plotShift = plotShift + [0, -15 + -18*numel(strfind(plotTitle, newline))];
end
plotHandle = figureSize(plotHandle, plotSize); clf(plotHandle);
colormap([flip(gray(64),1); parula(64)]);
if ~isempty(plotTitle)
    figureTitle(plotHandle, plotTitle, 0.04*(1+numel(strfind(plotTitle, newline))));
end

if pl2D
    % Surface plots
    if ~isempty(title2); pCol = 2; end
    plotfun = @(y, z, s, opts) surf(y, z, s, 'EdgeColor', 'none', 'CDataMapping', 'direct', opts{:});
    resize = 'auto z';
else
    % 1D plots
    pCol = 1;
    plotfun = @(y, z, s, opts) plot( fi(numel(y)>numel(z), y, z), (s-min(s,[],"all"))/max(s-min(s,[],'all'),[],'all'), 'LineWidth', 4);
    P = (P-65)/63; E = (E-65)/63;
    colormap(flip(gray(128),1));
    resize = 'auto y';
end

% Optical mode
h = subplot_tight(1, pCol, 1, mgn);
h.Units = "pixels";
h.Position = h.Position + [plotShift, 0, 0];
if ~isempty(n)
    if pl2D
        axn = plotfun(ny*1e6, nz*1e6, n*64, {'FaceAlpha', 1 - indexDim});
    else
        axn = pcolor(nz*1e6, ny, n);
        axn.EdgeColor = 'none'; axn.FaceAlpha = 1 - indexDim;
        clim([3, max(3.5,max(n,[],"all"))]);
        h.ColorOrderIndex = 2;
    end
end
axis('tight', 'manual', resize); hold on;
ax1 = plotfun(Py*1e6, Pz*1e6, P*63 + 65, ...
             {'FaceAlpha', 'flat', 'AlphaData', alphaP, 'FaceColor', 'flat'});

if pl2D
    hold off; view(2); grid off;
    title(title1, 'FontSize', 12, 'FontName', 'Source Sans Pro');
    ylabel('Epitaxial Direction [µm]');
    xlabel('Transverse Direction [µm]');
else
    xlabel('Epitaxial Depth [µm]');
    ylabel("Normalized Power"+fieldLabel, 'FontSize', 14);
    ylabel(colorbar, "Index");
    h.ColorOrderIndex = 1;
end


% Electric field, target mode, or second mode
if ~isempty(title2)
    if pCol == 2
        h2 = subplot_tight(1, pCol, pCol, mgn);
        h2.Units = "pixels";
        h2.Position = h2.Position + [plotShift, 0, 0];
    end
    if ~isempty(n) && (pl2D && pCol == 2)
        axn = plotfun(ny*1e6, nz*1e6, n*64, {'FaceAlpha', 1 - indexDim});
        hold on;
        axis('tight', 'manual', resize);
    end
    ax2 = plotfun(Ey*1e6, Ez*1e6, E*63 + 65, ...
                 {'FaceAlpha', 'flat', 'AlphaData', alphaE, 'FaceColor', 'flat'});
    if pl2D
        hold off; view(2); grid off;
        title(title2, 'FontSize', 12, 'FontName', 'Source Sans Pro');
        xlabel('Transverse Direction [µm]');
    end
else
    ax2 = [];
end

% 3rd mode for 1D plots only
if exist('title3', 'var')
    h.ColorOrderIndex = 3;
    ax3 = plot( fi(numel(E2y)>numel(E2z), E2y*1e6, E2z*1e6), E2, ':', 'LineWidth', 2);
else
    ax3 = []; title3 = "";
end

% If 1D, legends and swap ordering
if ~pl2D
    legend([axn, ax1, ax2, ax3], "Index", title1, title2, title3, 'location', 'sw');
    grid on;
    h.Children(1:end-1) = flip(h.Children(1:end-1));
end    

drawnow;

if ~isempty(saveFile) && ~(isstring(saveFile) && strlength(saveFile) == 0)
    [savePath, saveName] = fileparts(saveFile);
    if strlength(savePath) == 0; savePath = "."; end
    print(savePath + "/" + matlab.lang.makeValidName(saveName) + ".png", '-dpng');
end


end
