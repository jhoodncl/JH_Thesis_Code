function [f, varargout] = mass2freq(m,varargin)
% Function to convert mass [u] to freq [Hz]
%
% V1.0 - 22.03.19
%
%%% INPUTS %%%
% m = Ion mass vector, any length [u]
%
% varargin = Optional name-value pair inputs
% -- geometry = 3-element vector of trap geometry [R1 R2 Rm] [m]
% -- Ro       = Orbital radius [mm]
% -- KE       = Ion kinetic energy [eV]
% -- Vint     = Internal electrode voltage [V]
% One, and only one, of KE and Vint must be an input.
%
%
%%% OUTPUTS %%%
% f    = Frequency of oscillation for inputs mass(es) [Hz]
% Vint = Internal electrode Voltage [V] (Optional)
% KE   = Ion kinetic energy [eV] (Optional)
% k    = Field curvature [V/m^2] (Optional)

%
%
%%% EXAMPLES %%%
% f = mass2freq(100,'KE',101)
% => f = 1.5653e+05; % Freq. for 100u, 101eV ions
%
% f = mass2freq(100,'Vint',175)
% => f = 1.5656e+05; % Freq. for 100u ions with Vint = 175V
%
% f = mass2freq(100,'Vint',1000,'geometry',[9E-3 15E-3 22E-3])
% => f = 5.2814e+05; % Freq. for 100u ions, with Vint = 1000V in HF trap
%
% [f,Vint,KE] = mass2freq(100,'KE',100);
% => f    = 1.5575e+05; % Freq. for 100u, 101eV ions
%    Vint = 174.9253;   % Int. elec. voltage for STD geometry at 101eV
%    KE   = 100;        % Ion kinetic energy

%% CONSTANTS

q   = 1;              % Ion charge [e]
e_c = 1.6021766E-19;  % Elementary charge [C]
amu = 1.66053892E-27; % Atomic mass unit [kg]

%% OPTIONS - Parse optional name-value pair input arguments

% Define default options
% Trap Geometry
defR1    =  6E-3;               % Internal electrode radius [m]
defR2    = 15E-3;               % External electrode radius [m]
defRm    = 22E-3;               % Characteristic radius [m]
defGeom  = [defR1 defR2 defRm]; % Trap geometry vector [m]
defOrbit =  9E-3;               % Default orbital radius [m]

% Setup input parser
p = inputParser;
p.addParameter('geometry',defGeom); % [m]
p.addParameter('Ro',defOrbit);      % [m]
p.addParameter('KE',[]);            % [eV]
p.addParameter('Vint',[]);          % [V]

% Parse inputs
p.parse(varargin{:});

% Set inputs after parsing
R1 = p.Results.geometry(1); % [m]
R2 = p.Results.geometry(2); % [m]
Rm = p.Results.geometry(3); % [m]
Ro = p.Results.Ro;          % [m]

%% KE & Vint INPUT PARSER
% One, and only one, of KE or Vint must be input by user

% If BOTH KE & Vint are inputs
if (~ismember('KE',p.UsingDefaults)) && (~ismember('Vint',p.UsingDefaults))    
    error('Only one of KE or Vint can be an input.');   

% Elseif only Vint is input    
elseif (~ismember('Vint',p.UsingDefaults))
    Vint = p.Results.Vint; % Set Vint to user input  [V]

    % Calculate KE [eV]
    KE = 0.25*(Rm^2 - Ro^2)*(2*Vint)/(Rm^2*log(R2/R1) - 0.5*(R2^2 - R1^2));
    
% Elseif only KE is input    
elseif (~ismember('KE',p.UsingDefaults))
    KE = p.Results.KE; % Set KE to user input [eV]
       
    % Calculate Vint [V]
    Vint = 0.5*(Rm^2 * log(R2/R1) - 0.5*(R2^2 - R1^2))*4*KE/(Rm^2 - Ro^2);

% If NEITHER KE nor Vint are inputs    
else
    error('One, and only one, of KE or Vint must be an input.');   
end


%% CALCULATIONS

% Calculate field curvature, k, for this loop
k = 2*Vint/(Rm^2*log(R2/R1) - 0.5*(R2^2 - R1^2)); % [V/m^2]

% Calculate frequency
f = sqrt(q*e_c*k./(m*amu))./(2*pi); % [Hz]

%% OPTIONAL OUTPUTS

varargout{1} = Vint; % Internal electrode voltage [V]
varargout{2} = KE;   % Ion kinetic energy [eV]
varargout{3} = k;    % Field curvature [V/m^2]

end