%% plotResult3D.m  MN 2020-10-08
% Helper function to plot standardized Lumerical FDTD/EME3D/varFDTD results produced via lum_analyze.lsf
% 
% Requirements:
%   .mat file produced by lum_analyze with structures 'planarField', 'inputField', 'outputField'
% 
% Usage: [plotHandle] = plotResult3D(result, [options])
%   Returns:
%     plotHandle: handle to the plot
%
%   Parameters:
%     result: path to the result file to load or structure from same
%
%     Options:
%       'indexdim', double: dim index colormap by this much (default 0.4)
%       'title', string: overall title for the plot (default none)
%       'save', filename: save png of the plot
%       'handle', h: use this figure handle to plot
%       'size', [x, y]: figure size (default [1300, 1600])
%       'margin', [x, y]: subplot margin (default [0.10, 0.05])
%       'fixpeaks', outlierCutoff: try to fix erroneous plane-field peaks by removing outliers
%
% TODO:

function plotHandle = plotResult3D(result, varargin)
%% Defaults and magic numbers
indexDim = 0.4;
saveFile = [];
plotHandle = [];
plotTitle = [];
plotSize = [1600, 600];
mgn = [0.12, 0.05];


%% Argument parsing
% Check required inputs
if isempty(result) || (~isstruct(result) && (exist(result, 'file') ~= 2))
    error('Required input "result" is not a valid .mat file or structure!');
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
    switch string(arg)
        case "transparency"
            indexDim = double(nextarg('transparency value'));
        case "title"
            plotTitle = string(nextarg('plot title'));
        case "save"
            saveFile = string(nextarg('save filename'));
        case "handle"
            plotHandle = nextarg('plot handle');
            if ~isa(plotHandle, 'double') || ~isempty(ishandle(plotHandle)); plotHandle = []; end
        case "size"
            plotSize = double(nextarg('plot size'));
            if length(plotSize) < 2
                plotSize = repmat(plotSize,1,2);
            end
        case "margin"
            mgn = double(nextarg('margin'));
        case "fixpeaks"
            outlierCutoff = double(nextarg('outlier cutoff'));
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


%% Load data
if isstruct(result) && isfield(result, 'simData')
    R = result.simData;
else
    R = load(result);
end


%% Format results, assuming fields exist
% TODO: handle 1D
In = struct; Out = struct; Plane = struct;

if isfield(R, 'inputField')
    In.x = real(R.inputField.y)*1e6;
    In.y = real(R.inputField.z)*1e6;
    
    In.P = reshape(sum(mean(abs(R.inputField.E).^2, [1,4]),5), numel(In.x), numel(In.y));
    In.P = abs(smoothn(In.P, 2));
%     In.P = In.P ./ max(In.P, [], 'all'); % Normalized for color mapping
    
    % Calculate transparency
    In.alpha = isfield(In, 'n') + max(smoothn(In.P.^0.25, 5),0);
end
if isfield(R, 'inputIndex')
    assert(all(size(In.x) == size(R.inputField.y)));
    
    In.n = squeeze(mean(real(R.inputIndex.index), [1,4,5]));
    if numel(In.x) == 1; In.n = mean(In.n, 1); end
    if numel(In.y) == 1; In.n = mean(In.n, 2); end
end

if isfield(R, 'outputField')
    Out.x = real(R.outputField.y)*1e6;
    Out.y = real(R.outputField.z)*1e6;
    
    Out.P = reshape(sum(mean(abs(R.outputField.E).^2, [1,4]),5), numel(Out.x), numel(Out.y));
    Out.P = abs(smoothn(Out.P, 2));
%     Out.P = Out.P ./ max(Out.P, [], 'all'); % Normalized for color mapping
    
    % Calculate transparency
    Out.alpha = isfield(Out, 'n') + max(smoothn(Out.P.^0.25, 5),0);
end
if isfield(R, 'outputIndex')
    assert(all(size(Out.x) == size(R.outputIndex.y)));
    
    Out.n = squeeze(mean(real(R.outputIndex.index), [1,4,5]));
    if numel(Out.x) == 1; Out.n = mean(Out.n, 1); end
    if numel(Out.y) == 1; Out.n = mean(Out.n, 2); end
end

if isfield(R, 'planarField')
    Plane.x = real(R.planarField.x)*1e6;
    Plane.y = real(R.planarField.y)*1e6;
    
    Plane.P = reshape(sum(mean(abs(R.planarField.E).^2, [3,4]),5), numel(Plane.x), numel(Plane.y));
    Plane.P = abs(smoothn(Plane.P, 2));
    Plane.P = Plane.P ./ max(Plane.P, [], 'all'); % Normalized for color mapping
    
    % Calculate transparency
    Plane.alpha = isfield(Plane, 'n') + max(smoothn(Plane.P.^0.25, 5),0);
end
if isfield(R, 'planarIndex')
    assert(all(size(Plane.y) == size(R.planarIndex.y)));
    
    Plane.n = squeeze(mean(real(R.planarIndex.index), [3,4,5]));
    if numel(Plane.x) == 1; Plane.n = mean(Plane.n, 1); end
    if numel(Plane.y) == 1; Plane.n = mean(Plane.n, 2); end
end

% Normalize index
nMin = min([In.n(:); Out.n(:); Plane.n(:)]);
nMax = max([In.n(:); Out.n(:); Plane.n(:)]);
In.n = (In.n - nMin)/nMax;
Out.n = (Out.n - nMin)/nMax;
Plane.n = (Plane.n - nMin)/nMax;


%% Plot
    % Helper function
    function plotPanel(h, dat)
        % Check dimensionality
        if numel(dat.x) > 1 && numel(dat.y) > 1
            pl2D = 1;
            resize = 'auto z';
        else
            pl2D = 0;
            resize = 'auto xy';
            % Verify x is the longer dimension
            if numel(dat.x) == 1
                x = dat.x; dat.x = dat.y; dat.y = x;
                dat.n = dat.n(:); dat.P = dat.P(:); dat.alpha = dat.alpha(:);
            end
        end
        
        colormap([flip(gray(64),1); parula(64)]);
        
        % Plot index if exist
        if isfield(dat, 'n')
            if pl2D
                surf(dat.x, dat.y, dat.n'*64, 'EdgeColor', 'none', 'CDataMapping', 'direct', 'FaceAlpha', 1 - indexDim);
            else
                ax = pcolor([dat.x, dat.x]', [0;4], 64*[n, n]');
                ax.EdgeColor = 'none'; ax.FaceAlpha = 1 - indexDim; ax.CDataMapping = 'direct';
%                 clim([3, max(3.5, max(dat.n,[],"all"))]);
                h.ColorOrderIndex = 2;
            end
%             ylabel(colorbar, "Index");
            hold on;
        end
        
        % Plot power
        if isfield(dat, 'P')
            if pl2D
                dat.P = dat.P - min(dat.P, [], "all"); dat.P = dat.P/max(dat.P,[],'all');
                surf(dat.x, dat.y, dat.P'*63 + 65, 'EdgeColor', 'none', 'CDataMapping', 'direct', ...
                                                   'FaceAlpha', 'flat', 'AlphaData', dat.alpha', 'FaceColor', 'flat');
                view(2); grid off;
                if isfield(dat, 'ylabel'); ylabel(dat.ylabel, 'FontSize', 14, 'FontName', 'Source Sans Pro'); end
            else
                plot(dat.x, dat.P, 'LineWidth', 4);
%                 ylabel("Normalized Power", 'FontSize', 14, 'FontName', 'Source Sans Pro');
            end
        end
        axis('tight', 'manual', resize); hold on;
        hold off;

        if isfield(dat, 'title'); title(dat.title, 'FontSize', 14, 'FontName', 'Source Sans Pro'); end
        if isfield(dat, 'xlabel'); xlabel(dat.xlabel, 'FontSize', 14, 'FontName', 'Source Sans Pro'); end
    end

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

% Input
h = subplot_tight(1, 4, 1, mgn);
h.Units = "pixels";
h.Position = h.Position + [plotShift, 0, 0];
plotPanel(h, In);

% Planar
h = subplot_tight(1, 4, [2,3], mgn);
h.Units = "pixels";
h.Position = h.Position + [plotShift, 0, 0];
plotPanel(h, Plane);

% Output
h = subplot_tight(1, 4, 4, mgn);
h.Units = "pixels";
h.Position = h.Position + [plotShift, 0, 0];
plotPanel(h, Out);

drawnow;

if ~isempty(saveFile) && ~(isstring(saveFile) && strlength(saveFile) == 0)
    [savePath, saveName] = fileparts(saveFile);
    if strlength(savePath) == 0; savePath = "."; end
    print(savePath + "/" + matlab.lang.makeValidName(saveName) + ".png", '-dpng');
end



end
