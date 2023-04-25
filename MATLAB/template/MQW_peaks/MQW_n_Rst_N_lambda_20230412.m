%% Load, process, and plot MQW simulation result data
% Michael Nickerson 2023-04-12

clear; close('all');


%% Simulation-specific definitions
% Load definitions
def_MQW_peaks; clear script setVars;

% Set customizations
dualMode = 0;
sweepName = "MQW_nominal_cden";
ltarget = 0.98;


%% Definitions
componentName = scriptName;

% Files to load
resFiles = dir("./sweeps/" + sweepName + "/" + scriptName+"*.mat");
resFiles = string({resFiles.folder}') + "\" + string({resFiles.name}');


%% Load data files
% Initialize storage
N = []; % Carrier density
lambda = [];  % Wavelength vector; should not change between results
gTE = [];
gTM = [];
gspTE = [];
dnTE = []; % Delta-index

% Loading loop
fprintf("Loading files: "); lastOut = '';
for i = 1:numel(resFiles)
    lastOut = utilDisp(sprintf('%i/%i', i, numel(resFiles)), lastOut);
    
    R = load(resFiles(i));
    
    % Process
    excludeBarriers = sum(R.mqw.length) / (R.Nqw * R.tQW*1e-6);  % Scale to remove barriers
    N(end+1,:) = R.mqw.cden * excludeBarriers * 0.85; % 0.85 is empirical fraction-of-charge-in-wells that Lumerical application notes use
    if ~isempty(lambda)
        assert(all(size(lambda) == size(R.mqw.index.wavelength)) && all(lambda == R.mqw.index.wavelength));
    else
        lambda = R.mqw.index.wavelength;
    end
    gTE(end+1,:) = R.mqw.emission.stimulated_TE * excludeBarriers;
    gTM(end+1,:) = R.mqw.emission.stimulated_TM * excludeBarriers;
    gspTE(end+1,:) = R.mqw.emission.spontaneous_TE * excludeBarriers;
    dnTE(end+1,:) = R.mqw.index.index_TE * excludeBarriers;    % Scales correctly as this is n-n0
end
utilDisp(sprintf("done.\n\n"), lastOut);

% Sort by N and lambda, smooth, and convert to 1e24 m^-3, µm, and cm^-1/QW units
[N, iN] = sort(N/1e24);
[lambda, iL] = sort(lambda*1e6);
gTE   = smoothdata(gTE(iN, iL)/100/R.Nqw, 2, 'gaussian', 3);
gTM   = smoothdata(gTM(iN, iL)/100/R.Nqw, 2, 'gaussian', 3);
gspTE = smoothdata(gspTE(iN, iL)/100/R.Nqw, 2, 'gaussian', 3);
dnTE  = dnTE(iN, iL);

% Crop by lambda
iL = lambda > 0.6 & lambda < 1.2;
lambda = lambda(iL);
gTE   = gTE(:, iL);
gTM   = gTM(:, iL);
gspTE = gspTE(:, iL);
dnTE  = dnTE(:, iL);


%% Plot peak and target wavelength material gain vs. N
[~, il] = sort(abs(lambda-ltarget)); il = il(1);
plotStandard2D([N, max(gTE, [], 2)*R.Nqw], 'legend', 'g_{TE} @ Peak', ...
               [N, gTE(:, il)*R.Nqw], 'legend', sprintf("g_{TE} @ %i nm", ltarget*1e3), ...
               'xla', 'Carrier Density [1e18 cm^{-3}]', ...
               'yla', 'Material Gain [cm^-1]', 'yra', [-2000, 5000], ...
               'title', sprintf("%i nm QW Gain, N=%i", ltarget*1e3, R.Nqw), ...
               'legendloc', 'se', 'fig', 5, ...
               'save', sprintf("%i nm Material Gain vs N.png", ltarget*1e3));


%% Plot material gain vs. lambda, multiple N traces
plotParts = {};
for i = 1:size(gTE,1)
    plotParts = [plotParts, {[lambda, gTE(i,:)'*R.Nqw], 'LineWidth', 1}];
end
plotStandard2D(plotParts, ...
               'xla', 'lambda [µm]', 'xra', [0.8, 1.1], ...
               'yla', 'Material Gain [cm^-1]', 'yra', [-2000, 5000], ...
               'title', sprintf("%i nm QW Gain, N=%i", ltarget*1e3, R.Nqw), ...
               'legendloc', 'se', 'fig', 6, ...
               'save', sprintf("%i nm Material Gain vs lambda.png", ltarget*1e3));


%% Fit at each wavelength to try to determine best coefficients
% Coefficient matrices and fit options
g0 = lambda*NaN; Ntr = g0; Rsq = g0;
ft = fittype( 'g0*2*(0.5-exp(-N/Ntr))', 'independent', 'N');
sp = [2 2000];
lb = [0, 0];

% Wavelength sweep
fprintf("Fitting: "); lastOut = '';
for i = 1:numel(lambda)
    lastOut = utilDisp(sprintf('%i/%i', i, numel(lambda)), lastOut);
    [fit_gTE, gof] = fit(N, gTE(:, i), ft, 'lower', lb, 'startpoint', sp);
%     sp = coeffvalues(fitL);
    g0(i) = fit_gTE.g0; Ntr(i) = fit_gTE.Ntr; Rsq(i) = gof.rsquare;
end
utilDisp(sprintf("done.\n\n"), lastOut);

% Plot coefficients by wavelength
plotStandard2D([lambda, g0], 'legend', 'g0', ...
               [lambda, Ntr*100], 'y1', 'legend', 'Ntr*100', ...
               [lambda, Rsq], 'y2', 'legend', 'Rsq', ...
               'xla', 'lambda [µm]', 'yla', 'g0 [cm^-1], Ntr [100*1e24 m^-3]', 'y2la', 'Rsq', 'fig', 1);


%% Fit g0(lambda) and plot
[fit_g0, gof] = fit(lambda, g0, fittype('(g00 + g01*(l-l0))*(1-tanh((l-l0)/dl))/2', 'independent', 'l') , ...
                    'startpoint', [0.05, 2000, 1200, 1.06])

plotStandard2D([lambda, g0], 'legend', 'g0', ...
               [lambda, fit_g0(lambda)], 'legend', 'g0 fit', 'LineWidth', 2, 'style', ':', ...
               'xla', 'lambda [µm]', 'yla', 'g0 [cm^-1], Ntr [100*1e24 m^-3]', 'fig', 2);


%% Fit Ntr(lambda) and plot
[fit_Ntr, gof] = fit(lambda, Ntr, ...
                     fittype('(N00 + N01*(l-l1)^2) * (1-tanh((l-l0)/dl))/2 + (N10 + N11*(l-l2)^2) * (1+tanh((l-l0)/dl))/2', 'independent', 'l'), ...
                    'startpoint', [0.6, 200, 8, -20, 0.01, 1.06, 1.1, 1.5])

plotStandard2D([lambda, Ntr], 'legend', 'Ntr', ...
               [lambda, fit_Ntr(lambda)], 'legend', 'Ntr fit', 'LineWidth', 2, 'style', ':', ...
               'xla', 'lambda [µm]', 'yla', 'g0 [cm^-1], Ntr [100*1e24 m^-3]', 'fig', 3);


%% 3D fit combining everything: gTE
[NN, ll] = ndgrid(N, lambda);
ft = fittype('(g00 + g01*(l-l0))*(1-tanh((l-l0)/dl))/2 *2* (0.5-exp(-N/ ((N00 + N01*(l-l1)^2) * (1-tanh((l-l0)/dl))/2 + (N10 + N11*(l-l2)^2) * (1+tanh((l-l0)/dl))/2) ))', 'independent', {'N', 'l'});
[fit_gTE, gof] = fit([NN(:), ll(:)], gTE(:), ft, ...
                     'StartPoint', [0.6, 200, 8, -20, 0.01, 2000, 1200, 1.06, 1.1, 1.5], ...
                     'Lower', [0, 0, 0, -Inf, 0, -Inf, -Inf, 0.5, 1, 1], ...
                     'Display', 'off', 'Robust', 'LAR', 'MaxFunEvals', 3e3, 'MaxIter', 2e3)

figure(4);
scatter3(NN, ll, gTE, 'filled', 'k'); hold on;
surf(NN, ll, fit_gTE(NN, ll), 'FaceAlpha', 0.5); hold off;


%% 3D fit combining everything: gTM
ft = fittype('g00*(1-tanh((l-l0)/dl))/2 *2* (0.5-exp(-N/ ((N00 + N01*(l-l1)^2) * (1-tanh((l-l0)/dl))/2 + (N10 + N11*(l-l2)^2) * (1+tanh((l-l0)/dl))/2) ))', 'independent', {'N', 'l'});
[fit_gTM, gof] = fit([NN(:), ll(:)], gTM(:), ft, ...
                     'StartPoint', [10, 200, 25, -0.1, 0.1, 1500, 0.9, 1.1, 1.5], ...
                     'Lower', [1e-3, 1e-3, 1e-3, -Inf, 1e-3, 0.5, 0.1, 0.1, 0.1], ...
                     'Display', 'off', 'Robust', 'LAR', 'MaxFunEvals', 3e3, 'MaxIter', 2e3)

figure(4);
scatter3(NN, ll, gTM, 'filled', 'k'); hold on;
surf(NN, ll, fit_gTM(NN, ll), 'FaceAlpha', 0.5); hold off;


%% 3D fit combining everything: gspTE
% ft = fittype('(g00 + g01*(l-l0))*(1-tanh((l-l0)/dl))/2 *2* (0.5-exp(-N/ ((N00 + N01*(l-l1)^2) * (1-tanh((l-l0)/dl))/2 + (N10 + N11*(l-l2)^2) * (1+tanh((l-l0)/dl))/2) ))', 'independent', {'N', 'l'});
% [fit_gspTE, gof] = fit([NN(:), ll(:)], gspTE(:), ft, ...
%                      'StartPoint', [-0.1, 8, 1.4, -0.1, 0.05, 1100, 3800, 1.06, 1.1, 1.5], ...
%                      'Lower', [-Inf, 0, 0, -Inf, 0, 0, 0, 1, 1, 1], ...
%                      'Display', 'off', 'Robust', 'LAR', 'MaxFunEvals', 3e3, 'MaxIter', 2e3)

% Needs a separate fit with a different function, likely based on 'g0*(1-exp(-N/Ntr))'

figure(4);
scatter3(NN, ll, gspTE, 'filled', 'k'); %hold on;
% surf(NN, ll, fit_gspTE(NN, ll), 'FaceAlpha', 0.5); hold off;


%% 3D fit combining everything: imag(dnTE)
ft = fittype('(g00 + g01*(l-l0))*(1-tanh((l-l0)/dl))/2 *2* (0.5-exp(-N/ ((N00 + N01*(l-l1)^2) * (1-tanh((l-l0)/dl))/2 + N10 * (1+tanh((l-l0)/dl))/2) ))', 'independent', {'N', 'l'});
[fit_idnTE, gof] = fit([NN(:), ll(:)], -imag(dnTE(:)), ft, ...
                     'StartPoint', [2, 200, 5, 0.01, 0.05, 0.07, 1.06, 1.1], ...
                     'Lower',      [0, 0, 0,    0,    0, 1e-3,    1,   1], ...
                     'Display', 'off', 'MaxFunEvals', 3e3, 'MaxIter', 2e3)

figure(4);
scatter3(NN, ll, -imag(dnTE), 'filled', 'k'); hold on;
surf(NN, ll, fit_idnTE(NN, ll), 'FaceAlpha', 0.5); hold off;


%% 3D fit combining everything: real(dnTE)
% ft = fittype('(g00 + g01*(l-l0))*(1-tanh((l-l0)/dl))/2 *2* (0.5-exp(-N/ ((N00 + N01*(l-l1)^2) * (1-tanh((l-l0)/dl))/2 + N10 * (1+tanh((l-l0)/dl))/2) ))', 'independent', {'N', 'l'});
% [fit_rdnTE, gof] = fit([NN(:), ll(:)], real(dnTE(:)), ft, ...
%                      'StartPoint', [2, 200, 5, 0.01, 0.05, 0.07, 1.06, 1.1], ...
%                      'Lower',      [0, 0, 0,    0,    0, 1e-3,    1,   1], ...
%                      'Display', 'off', 'MaxFunEvals', 3e3, 'MaxIter', 2e3)

% Needs a separate fit with a different function, possibly based on 'dn0*(1-exp(-N/Ntr))'

figure(4);
scatter3(NN, ll, real(dnTE), 'filled', 'k'); %hold on;
% surf(NN, ll, fit_rdnTE(NN, ll), 'FaceAlpha', 0.5); hold off;


%% Save fit
save('PV980_MQW_N_lambda.mat', 'sweepName', 'N', 'lambda', 'gTE', 'gTM', 'gspTE', 'dnTE', ...
                             'fit_gTE', "fit_gTM", "fit_idnTE")
return;

%% Alternate lambda fit
% a0 = lambda*NaN; Ns=a0; Ntr=a0; a1=a0; b1=a0; Rsq=a0;
% ft = fittype( 'a0*log((N+Ns)/(Ntr+Ns))+a1*(0.5-exp(-N/b1))', 'independent', 'N');
% lb = [0 0 0 -Inf 0];
% sp = [1 2 500 500 2];
% 
% % Wavelength sweep
% fprintf("Fitting: "); lastOut = '';
% for i = numel(lambda):-1:1  % Reverse gives cleaner fits when using previous fit's values as a starting point
%     lastOut = utilDisp(sprintf('%i/%i', i, numel(lambda)), lastOut);
%     [fitL, gof] = fit(N, gTE(:, i), ft, 'lower', lb, 'startpoint', sp);
%     sp = coeffvalues(fitL);
%     a0(i)=fitL.a0; Ns(i)=fitL.Ns; Ntr(i)=fitL.Ntr; a1(i)=fitL.a1; b1(i)=fitL.b1; Rsq(i) = gof.rsquare;
% end
% utilDisp(sprintf("done.\n\n"), lastOut);
% 
% % Plot coefficients by wavelength
% plotStandard2D([lambda, log(a0)], 'legend', 'a0', ...
%                [lambda, log(Ns)], 'legend', 'b0', ...
%                [lambda, Ntr], 'y2', 'legend', 'c0', ...
%                [lambda, a1], 'y2', 'legend', 'a1', ...
%                [lambda, b1], 'y2', 'legend', 'b1', ...
%                'xla', 'lambda [µm]', 'yla', 'a0, b0', 'y2la', 'c0, a1, b1', 'fig', 1);
% plotStandard2D([lambda, Rsq], 'legend', 'Rsq', ...
%                'xla', 'lambda [µm]', 'fig', 2);


%% Helper functions
% Display helper
function out = utilDisp(out, varargin)
    if numel(varargin) > 0; lastout = varargin{1}; else; lastout = ''; end
    
    fprintf(repmat('\b', 1, numel(sprintf(lastout))));
    fprintf(out);
end
