%% plotMQW.m  MN 2022-10-11
% Helper function to plot Lumerical MQW results
% 
% Requirements:
%   .mat file with `mqw` structure produced by addMQW() in 'lum_analyze'
% 
% Usage: [plotHandle] = plotMQW(result, [options])
%   Returns:
%     plotHandle: handle to the plot
%
%   Parameters:
%     result: path to the result file(s) to load or structure from same; wildcards accepted
%
%     Options:
%       'title', string: overall title for the plot (default none)
%       'save', filename: save png of the plot
%       'handle', h: use this figure handle to plot
%       'size', [x, y]: figure size (default [1600, 600])
%       'margin', [x, y]: subplot margin (default [0.10, 0.05])

function plotHandle = plotMQW(result, varargin)
%% Defaults and magic numbers
saveFile = [];
plotHandle = [];
plotTitle = "";
plotSize = [1600, 600];
mgn = [0.10, 0.05];
plotShift = [0, 0];


%% Argument parsing
% Check required inputs
if isempty(result) || ( (~isstruct(result)) && (exist(result, 'file') ~= 2 && (numel(dir(result)) < 1) ) )
    error('Required input "result" is empty or does not correspond to any valid files.');
end

% Parameter parsing
while ~isempty(varargin)
    arg = lower(varargin{1}); varargin(1) = [];
    
    % Look for options
    switch lower(string(arg))
        case "title"
            plotTitle = string(nextarg('plot title'));
        case "save"
            saveFile = string(nextarg('save filename'));
        case "handle"
            plotHandle = nextarg('plot handle');
            if ~(isa(plotHandle, 'double') || ishandle(plotHandle))
                plotHandle = [];
            end
        case "size"
            plotSize = double(nextarg('plot size'));
            if numel(plotSize) < 2
                plotSize = repmat(plotSize,1,2);
            end
        case "margin"
            mgn = double(nextarg('margin'));
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

if ~isfield(R, 'mqw')
    fprintf("Cannot plot '%s'\n", result);
    return;
end
mqw = R.mqw;


%% Break out variables for readability
% Band diagram
z = mqw.banddiagram.z*1e9;
Ec = mqw.banddiagram.Ec;
Ev = mqw.banddiagram.Ev;

% Composition and strain
if isfield(mqw, 'length') && isfield(mqw, 'strain')
    length = reshape(repmat(cumsum(mqw.length'), 2, 1), 1, [])*1e9;
    length = [0,length(1:end-1)];
    strain = reshape(repmat(mqw.strain', 2, 1), 1, []);
    plotShift = plotShift + [35, 0]; mgn = mgn + [0, 0.015];
end

% Emission
lv = mqw.emission.wavelength*1e6;
TE = squeeze(mqw.emission.spontaneous_TE);
TM = squeeze(mqw.emission.spontaneous_TM);

% Naming: materials
% matLabel = titlewrap(strrep(mqw.materials, "_", " /"), 140, "/");


%% Plot
% Title and figure
if ~isempty(plotTitle)
    plotTitle = titlewrap(plotTitle, 140);% + newline;
end
% plotTitle = plotTitle + matLabel;
% Increase size for larger title
plotSize = plotSize + [0, 120*numel(strfind(plotTitle, newline))];
plotShift = plotShift + [0, -0 + -15*numel(strfind(plotTitle, newline))];
plotHandle = figureSize(plotHandle, plotSize); clf(plotHandle);

if ~isempty(plotTitle)
    figureTitle(plotHandle, plotTitle, 0.03*(1.5+numel(strfind(plotTitle, newline))), ...
                "Interpreter", "none", "FontSize", 14);
end

% Band structure
h = subplot_tight(1, 2, 1, mgn);
h.Units = "pixels"; h.Position = h.Position + [plotShift.*[-1, 1], 0, 0];
ax = plot(z, Ec, 'LineWidth', 4);
hold on;
ax = [ax, plot(z, Ev, 'LineWidth', 4)];
xlabel('Epitaxial Depth [nm]', 'FontWeight','bold');
ylabel('Energy [eV]', 'FontWeight','bold');
h.XLimitMethod = "tight"; h.YLim = [-0.5, max([Ec;1.8])];
if exist('strain', 'var')
    yyaxis(h, 'right'); h.YLim = [-1, 1]*0.04;
    ax = [ax, plot(length, strain, ':', 'LineWidth', 2)];
    ylabel('Strain [fractional]', 'FontWeight','bold');
%     ax(end).YColor = 
end
hold off; grid on; 
title("MQW Structure", 'FontSize', 14, 'FontName', 'Source Sans Pro');
legend(ax, ["Ec", "Ev", "Strain"], 'FontSize', 14, 'Location', 'ne');

% Emission
h = subplot_tight(1, 2, 2, mgn);
h.Units = "pixels"; h.Position = h.Position + [plotShift, 0, 0];
ax = plot(lv, TE, 'LineWidth', 4);
hold on;
ax = [ax, plot(lv, TM, ':', 'LineWidth', 2)];
ylabel('Rsp [arb]', 'FontWeight','bold');
xlabel('Wavelegnth [µm]', 'FontWeight','bold');
hold off; grid on; h.XLim = [0.9,1.3];
title("MQW Emission", 'FontSize', 14, 'FontName', 'Source Sans Pro');
legend(ax, ["TE", "TM"], 'FontSize', 14, 'Location', 'ne');

drawnow;

if ~isempty(saveFile)
    [savePath, saveName] = fileparts(saveFile);
    if strlength(savePath) == 0; savePath = "."; end
    print(savePath + "/" + matlab.lang.makeValidName(saveName) + ".png", '-dpng');
end


end
