%% analyticalModelGaAs.m
%   Michael Nickerson 2022-09-30
%   Index modulation and optical absorption model for GaAs
% 
% Requirements:
%   - 
% 
% Usage: [dn, dalpha, n] = analyticalModelGaAs(fieldOptical, fieldElectrical[, option, [value]])
%   Returns:
%     dn:       effective index alteration
%     alpha:    optical absorption [cm^-1]
%     V:        array of corresponding bias points
%     n:        absolute complex index, size [x, y, (TE,TM), numel(V)]
%
%   Parameters: units of meters, with lambda in µm
%     fieldOptical:    structure with fields 'y', 'z', and 'E' describing the optical field; can
%                          include multiple modes as extra dimension, vectorizing dn and dalpha
%     fieldElectrical: structure with fields 'y', 'z', and 'E' describing the DC electric field [V/m]
%                          Optionally include 'Vbias' vector and extra 'E' dimensions to calculate 
%                          assumed-linear response. Note: only Ez component used, assumed if scalar.
%
%     Options:
%       'lambda', <double>: wavelength [µm] (default 1.03)
%       'index', <matrix>: optical index matrix matching fieldOptical size; default
%           fieldOptical.index or GaAs index
%       'n', <structure>: electron concentration [cm^-3] specified as in fieldElectrical with field 'n'
%       'p', <structure>: hole concentration [cm^-3] specified as in fieldElectrical with field 'p'
%           Note: 'n' and 'p' can also be included as fields in fieldElectrical
%       'r41', @(n): override LEO effects
%       'R', @(A, n): override QEO effects
%       'dnBS', @(N, P): override band-gap shift effects
%       'dnFC', @(N, P, n): override free carrier plasma effects; N x n sized return
%
% TODO:
%   x Initial development
%   x Test
%   x Allow individual effects to be extracted

function [dn, alpha, V, n] = analyticalModelGaAs(fieldOptical, fieldElectrical, varargin)
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
    
    % 2D trapz
    function r = trapz2(x, y, f)
        if numel(x) == 1; x = [0,1]; f = repmat(f, [2 1 1]); end
        if numel(y) == 1; y = [0,1]; f = repmat(f, [1 2 1]); end
        r = trapz(x, trapz(y, f, 2));
    end


%% Defaults and magic numbers
lambda = 1.03;

% Physical constants and definitions [cm g s J], with lambda in µm
eV = 1.60218e-19;   % J
c = 2.99792458e10;  % cm/s
h = 6.62607e-34;    % J*s

% System definitions
Eg = 1.424;     % eV

% Derived constants
nGaAs = @(lambda) (0.6342 + 0.3775*(lambda).^2 ./ ((lambda).^2 - 0.1125)) .* 3.28;


%% Argument parsing
% Check required inputs
assert( ~(isempty(fieldOptical) || ~isa(fieldOptical, 'struct')), ...
        'Required input "fieldOptical" is not a struct!');
assert( ~(isempty(fieldElectrical) || ~isa(fieldElectrical, 'struct')), ...
        'Required input "fieldElectrical" is not a struct!');

% Parameter parsing
while ~isempty(varargin)
    arg = lower(varargin{1}); varargin(1) = [];
    
    % Look for valid arguments
    switch arg
        case {'lambda', 'wavelength'}
            lambda = double(nextarg('operating wavelength [µm]'));
        case 'n'
            N0 = nextarg('electron concentration');
        case 'p'
            P0 = nextarg('hole concentration');
        case 'index'
            index = double(nextarg('optical index'));
        case 'r41'
            r41 = nextarg('LEO effects, @(n)');
            if ~isa(r41, 'function_handle') || nargin(r41) ~= 1; clear('r41'); end
        case 'r'
            R = nextarg('QEO effects, @(A, n)');
            if ~isa(R, 'function_handle') || nargin(R) ~= 2; clear('R'); end
        case 'dnbs'
            dnBS = nextarg('Band-gap shift effects, @(N, P)');
            if ~isa(dnBS, 'function_handle') || nargin(dnBS) ~= 2; clear('dnBS'); end
        case 'dnfc'
            dnFC = nextarg('Free carrier plasma effects, @(N, P, n)');
            if ~isa(dnFC, 'function_handle') || nargin(dnFC) ~= 3; clear('dnFC'); end
        otherwise
            if ~isempty(arg)
                warning('Unexpected option "%s", ignoring', num2str(arg));
            end
    end
end


%% Validate inputs
% fieldOptical:   structure with fields 'y', 'z', and 'E' describing the optical field; can
assert( isfield(fieldOptical, 'y'), 'No "y" vector present in "fieldOptical"');
assert( isfield(fieldOptical, 'z'), 'No "z" vector present in "fieldOptical"');
assert( isfield(fieldOptical, 'E'), 'No "E" field present in "fieldOptical"');

% Assemble index if not specified
if ~exist('index', 'var') && isfield(fieldOptical, 'index')
    index = fieldOptical.index;
elseif ~exist('index', 'var')
    index = nGaAs(lambda) + 0*fieldOptical.E;
end

% fieldElectrical:structure with fields 'y', 'z', and 'E' describing the DC electric field
assert( isfield(fieldElectrical, 'y'), 'No "y" vector present in "fieldElectrical"');
assert( isfield(fieldElectrical, 'z'), 'No "z" vector present in "fieldElectrical"');
assert( isfield(fieldElectrical, 'E'), 'No "E" field present in "fieldElectrical"');

% Assemble N and P if not specified
if ~exist('N', 'var') && isfield(fieldElectrical, 'n')
    N0 = struct('y', fieldElectrical.y, 'z', fieldElectrical.z, 'N', fieldElectrical.n);
elseif ~exist('N', 'var')
    N0 = fieldElectrical; N0.N = 0*N0.E; N0 = rmfield(N0, 'E');
elseif isfield(N0, 'n') && ~isfield(N0, 'N')
    N0.N = N0.n; N0 = rmfield(N0, 'n');
end
if ~exist('P', 'var') && isfield(fieldElectrical, 'p')
    P0 = struct('y', fieldElectrical.y, 'z', fieldElectrical.z, 'P', fieldElectrical.p);
elseif ~exist('P', 'var')
    P0 = fieldElectrical; P0.P = 0*P0.E; P0 = rmfield(P0, 'E');
elseif isfield(P0, 'p') && ~isfield(P0, 'P')
    P0.P = P0.p; P0 = rmfield(P0, 'p');
end

% Set Vbias if unspecified
if ~isfield(fieldElectrical, 'Vbias'); fieldElectrical.Vbias = -10; end


%% Extract data from inputs
% Not using x coordinate, but input is in full 3D data format
EO = reshape(fieldOptical.E(1,:,:,:), size(fieldOptical.E, 2:4));

% Check index
assert(numel(index) == numel(EO) || numel(index) == 3*numel(EO) || numel(index)*3 == numel(EO), "Error: index size does not match fieldOptical size");

% Verify index in correct shape
index = reshape(index, [size(EO, 1:2), size(index,3)]);


% Determine voltage sweep parameters
V = sort(fieldElectrical.Vbias, 'descend');
S = numel(V);

% Use the optical field's coordinates as a basis for everything; change everything else to the same geometry
% [y, z] = ndgrid(fieldOptical.y(:), fieldOptical.z(:)');
y = fieldOptical.y(:); z = fieldOptical.z(:)';

% Resample electrical data
Ej = zeros([numel(y), numel(z), S]); N = Ej; P = Ej;
for i = 1:S
    if size(fieldElectrical.E, 4) < 3   % Assume scalar Ez specified
        Ej0 = squeeze(fieldElectrical.E(1,:,:,1,i));
    else    % Select Ez component
        Ej0 = squeeze(fieldElectrical.E(1,:,:,3,i));
    end
    % Also convert to V/cm
    Ej(:,:,i) = interpn(fieldElectrical.y(:), fieldElectrical.z(:)', Ej0 * 1e-2, y, z, 'linear', 0);
    N(:,:,i)  = interpn(N0.y(:), N0.z(:)', squeeze(N0.N(1,:,:,1,i)), y, z, 'linear', 0);
    P(:,:,i)  = interpn(P0.y(:), P0.z(:)', squeeze(P0.P(1,:,:,1,i)), y, z, 'linear', 0);
end

% Insert synthetic data if needed and possible to obtain quadratic fit; assumes linearity
%   For best results, simulate intermediate value
if S == 2
    V(3) = V(1)+diff(V)/2;
    Ej(:,:,3) = Ej(:,:,1) + diff(Ej, 1, 3)/2;
    N(:,:,3)  = N(:,:,1)  + diff(N, 1, 3)/2;
    P(:,:,3)  = P(:,:,1)  + diff(P, 1, 3)/2;
    S = 3;
end


%% Index modulation effects: see '2022-08-30 - Analytical Model.nb' and 'Coefficient_Fits_2022_08_30.m'
Eph = h*c./(lambda*1e-4)/eV; % eV

% EO effects [cm g s J]
if ~exist('r41', 'var'); r41 = @(n) 1e-10 * (7.788 - 72.16 ./ n.^2); end
if ~exist('R', 'var'); R = @(A, n) 1e-16 * A * Eph ./ (n.^4 .* (Eg^2 - Eph.^2).^2); end
A_TE = 167.7; A_TM = 198.5;
dnEO_TE = @(Ej, n) -0.5 * n.^3 .* ( r41(n) .* Ej + R(A_TE, n) .* Ej.^2 );
dnEO_TM = @(Ej, n) -0.5 * n.^3 .* ( R(A_TM, n) .* Ej.^2 );

% Carrier effects
if ~exist('dnBS', 'var'); dnBS = @(N, P) ((-2.92e-21 + 8.9e-22)*N + (-2.92e-21 + 1.42e-21)*P) ./ (Eg^2 - Eph.^2); end
if ~exist('dnFC', 'var'); dnFC = @(N, P, n) -2.9e-22 * P ./ Eph.^2 + ...
                                           -(1.09e-20 * N + 1.352e-21 * P) ./ (n .* Eph.^2); end
%   TODO: carrier effects should not be negative here! But this matches data
dnNP = @(N, P, n) -(dnBS(N, P) + dnFC(N, P, n));


%% Absorption effects: see 'Coefficient_Fits_2022_08_30.m'
% Electroabsorption [cm g s J]
mu_lh = 0.0369; mu_hh = 0.0583;
betaj = @(mu, Ej) 1.1e5*(2*mu)^(1/3) * (Eg-Eph) .* abs(Ej).^(-2/3);
Aj = @(mu, n) 7.65e5*(2*mu)^(4/3)./(n .* Eph);
scale_fit = 0.08; % Empirical
alpha_FK = @(Ej, n) Ej.^(1/3) .* ( ...
                        Aj(mu_lh, n) .* (airy(1, betaj(mu_lh, Ej)).^2 - betaj(mu_lh, Ej) .* airy(0, betaj(mu_lh, Ej)).^2) + ...
                        Aj(mu_hh, n) .* (airy(1, betaj(mu_hh, Ej)).^2 - betaj(mu_hh, Ej) .* airy(0, betaj(mu_hh, Ej)).^2) ...
                    ) .* scale_fit;

% Carrier absorption
% mobility_N = @(N) 500 + (9400-500)./(1 + (N./6e16).^0.394);
% mobility_P = @(P) 20  + (491.5-20)./(1 + (P./1.48e17).^0.38);
% alpha_Drude_lh = @(lambda, N, P) 8.1e-17 * ( N./(0.063^2 * mobility_N(N)) + P./(0.082^2 * mobility_P(P)) ) ./ Eph.^2;

% Note that below is for doping - may not correctly correspond to free carriers! But seems to match
% measured performance more closely.
alpha_fit = @(N, P) 4.2*(N*1e-18).^0.8.*(lambda).^0.4 + 8*(P*1e-18).*(lambda).^3;

% Total absorption loss
alpha_total = @(Ej, N, P, n) alpha_FK(max(1e-2, Ej), n) + alpha_fit(N, P);


%% Calculations
% Calculate phase shift and optical absorption at each grid point
dn = zeros([numel(y), numel(z), 2, S]); % 2 polarizations only; ignore nx
alpha = zeros([numel(y), numel(z), S]);% scalar, averaged between polarizations
n = dn;
for i = 1:S
    % Calculate index shift and absorption
    dn(:,:,:,i) = dnNP(N(:,:,i), P(:,:,i), real(index(:,:,2:3)));
    dn(:,:,1,i) = dn(:,:,1,i) + dnEO_TE(Ej(:,:,i), real(index(:,:,2)));
    dn(:,:,2,i) = dn(:,:,2,i) + dnEO_TM(Ej(:,:,i), real(index(:,:,3)));
    alpha(:,:,i) = alpha_total(Ej(:,:,i), N(:,:,i), P(:,:,i), real(mean(index(:,:,2:3),3)));
    
    % Generate complex index
    n(:,:,:,i) = index(:,:,2:3) + dn(:,:,:,i) - i*alpha(:,:,i);
end

% Reduce to scalars via overlap with optical field: integral(|E_y|^2 * f_y + |E_z|^2 * f_z)/integral(|E|^2)
N_EO = trapz2(y, z, sum(abs(EO).^2, 3));
dn = arrayfun( @(i) trapz2(y, z, abs(EO(:,:,2)).^2 .* dn(:,:,1,i) + ...
                                 abs(EO(:,:,3)).^2 .* dn(:,:,2,i)) / N_EO, (1:S)');
alpha = arrayfun( @(i) trapz2(y, z, sum(abs(EO).^2,3) .* alpha(:,:,i)) / N_EO, (1:S)');


end

