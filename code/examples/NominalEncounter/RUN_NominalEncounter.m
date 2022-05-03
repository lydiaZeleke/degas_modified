% NominalEncounter wrapper
% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: X11
%
% This script shows how to go through the complete simulation pipeline for
% running a two aircraft encounter

% Switch to the directory that conains the simulation
simDir = which('NominalEncounter.slx');
[simDir,~,~] = fileparts(simDir);
cd(simDir);

resultsCombined = struct([]); 
% Input encounter number to simulate (Number 8 for setup scenario)

%% generate for 100 encounters %%
encNumArray = 60;

for i = 1: length(encNumArray)
    % Instantiate the simulation object
    encNum = encNumArray(i);
    s = NominalEncounterClass;
    
    % Setup the file to read the encounters from
    s.encounterFile = 'scriptedEncounters.mat';
    
    % Setup a metadata file associated with the encounters file
    s.metadataFile = 'metaData_copy.mat';
    
    % Setup the encounter. The encounter number is usually used as the input to
    % the function to set the random seed used in the simulation
    s.setupEncounter(encNum);
    
    % Run the simulation
    s.runSimulink(encNum);  
    
    % Plot the encounter geometry
    s.plot_noisy
    
    resultsCombined = s.injected_noisy_data(encNum, resultsCombined);
%     s.visualize_data(resultsCombined);
    % Read the well clear flag
    s.getSimulationOutput('WCMetrics');

    
end
%  generated_data = struct2table(resultsCombined);
%  writetable(generated_data,'exported_encounter_data_111.csv')
