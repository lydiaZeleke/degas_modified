classdef Simulation < BasicSimulation
% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: X11
%
% Simulation: The Simulation class populates various fields in the 
% end-to-end simulation object, such as `results`, `results_nominal`, 
% `estimates`, `analysis`, etc. The Simulation class also contains a plot 
% function that creates a figure containing various plots of interest.
%
% Simulink models used with classes derived from Simulation are required to
% have an output block labeled AircraftStatesOut that the AircraftState
% buses of all involved craft are sent to.
    
    properties(SetAccess=private)
        commonMetrics @ CommonMetrics % Collects common metrics from the simulation
        analysis @ SimulationAnalysis % Convenience methods for analyzing encounters
        warnings @ EncounterWarningCheck % Checks for common issues with the encounter     
    end    
    methods
        function obj = Simulation( model_name )
            %Construct a new DEGAS Simulation object
            %
            %   obj = Simulation( model_name )
            %
            % model_name - Base of Simulink model name.  example: 'NominalEncounter.slx' -> 'NominalEncounter'
            
            obj = obj@BasicSimulation( model_name );
            
            obj.commonMetrics = CommonMetrics( obj );
            
            obj.analysis = SimulationAnalysis( obj );
            
            obj.warnings = EncounterWarningCheck();
                        
        end

        function onSimulationComplete( obj, simObj )
            
            % First let commonMetrics and other child objects update
            % themselves
            obj.onSimulationComplete@BasicSimulation( simObj );         
            
            % Now pull out state trace if it exists
            obj.results(1).time = get( obj.simOut, 'tout' );
            obj.results_noisy(1).time = get( obj.simOut, 'tout' );
            obj.results_radar(1).time = get(obj.simOut, 'tout');
                
            % Update the results field
            aircraftStates = obj.getSimulationOutput( 'AircraftStatesOut' );
            assert( mod( size( aircraftStates, 2 ), AircraftStateBusReader.width ) == 0 );
            numAircraft = size( aircraftStates, 2 ) / AircraftStateBusReader.width;
            obj.results = repmat( obj.results(1), numAircraft, 1 );
            for aidx = 1 : numAircraft,
                acState = AircraftStateBusReader( aircraftStates(:,(aidx-1)*AircraftStateBusReader.width+(1:AircraftStateBusReader.width)) );
                obj.results(aidx).north_ft = acState.n_ft;
                obj.results(aidx).east_ft = acState.e_ft;
                obj.results(aidx).up_ft = acState.h_ft;
                obj.results(aidx).speed_ftps = acState.v_ftps;
                obj.results(aidx).psi_rad = acState.psi_rad;
                obj.results(aidx).theta_rad = acState.theta_rad;
                obj.results(aidx).phi_rad = acState.phi_rad;
                obj.results(aidx).vertical_speed_ftps = acState.dh_ftps;
                obj.results(aidx).hdd_ftps2 = acState.ddh_ftps2;
                obj.results(aidx).latitude_rad = acState.latLonAltState.lat_rad;
                obj.results(aidx).longitude_rad = acState.latLonAltState.lon_rad;
                obj.results(aidx).altitude_ft = acState.latLonAltState.alt_ft;
                obj.results(aidx).dLatitude_radps = acState.latLonAltState.dlat_radps;
                obj.results(aidx).dLongitude_radps = acState.latLonAltState.dlon_radps;
                obj.results(aidx).dAltitude_ftps = acState.latLonAltState.dalt_ftps;
            end

            err = [];
            try
                % Don't produce error if Simulink model lacks top-level
                % outport AircraftStateRatesOut
                aircraftStateRates = obj.getSimulationOutput( 'AircraftStateRatesOut' );
            catch err
            end
            if( isempty( err ) )
                assert( mod( size( aircraftStateRates, 2 ), AircraftStateRateBusReader.width ) == 0 );
                for aidx = 1 : numAircraft,
                    acStateRate= AircraftStateRateBusReader( aircraftStateRates(:,(aidx-1)*AircraftStateRateBusReader.width+(1:AircraftStateRateBusReader.width)) );
                    varNames = fields( acStateRate );
                    for k = 1 : numel(varNames),
                        obj.results(aidx).(varNames{k}) = acStateRate.(varNames{k});
                    end
                end
            end

%             err = [];
%             try
%                 % Don't produce error if Simulink model lacks top-level
%                 % outport AircraftEstimatesOut
%                 aircraftEstimates = obj.getSimulationOutput( 'AircraftEstimatesOut' );
%             catch err
%             end
%             if( isempty( err ) )
% %                 assert( mod( size( aircraftEstimates, 2 ), AircraftEstimateBusReader.width ) == 0 );
%                 for aidx = 1 : numAircraft,
%                     acEstimate= AircraftEstimateBusReader( aircraftEstimates(:,(aidx-1)*AircraftEstimateBusReader.width+(1:AircraftEstimateBusReader.width)) );
%                     varNames = fields( acEstimate );
%                     obj.estimates(aidx).time = obj.results(aidx).time;
%                     for k = 2 : numel(varNames),
%                         obj.estimates(aidx).(varNames{k}) = acEstimate.(varNames{k});
%                     end
%                 end
%             end            
            
            %%% Modification By Lydia for New Simulink Model %%%
               % Update the results field
            ownshipNoisyStates = obj.getSimulationOutput( 'NoisyOwnStatesOut' );
            assert( mod( size( ownshipNoisyStates, 2 ), AircraftStateBusReader.width ) == 0 );
            obj.results_noisy = repmat( obj.results_noisy(1), numAircraft, 1 );
            
            intruderNoisyStates = obj.getSimulationOutput( 'NoisyIntStatesOut' );                 
            intruderState = AircraftRadarConvertedStates( intruderNoisyStates(:,(1:7)) );
            ownshipNoisyStateRates = obj.getSimulationOutput( 'NoisyOwnStateRates' );
            ownStateRate= AircraftStateRateBusReader( ownshipNoisyStateRates(:,((1:AircraftStateRateBusReader.width)) ));
          
            %% Added for Visualizing Radar Parameters %%
            radarStates = obj.getSimulationOutput( 'RadarNoisyStates' );                 
            noisyRadarState = RadarStates( radarStates(:,(1:11)) );

            
            obj.results_radar.range_ft = noisyRadarState.range_ft;
            obj.results_radar.azimuth_rad = noisyRadarState.az_rad;
            obj.results_radar.elevation_rad = noisyRadarState.el_rad;
            obj.results_radar.range_dot = noisyRadarState.dRange_dtps;
            obj.results_radar.azdot_radps = noisyRadarState.azdot_radps;
            obj.results_radar.eldot_radps = noisyRadarState.eldot_radps;

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            for aidx = 1 : numAircraft,
                if aidx == 1
                    ownNoisyState = AircraftStateBusReader( ownshipNoisyStates(:,(aidx-1)*AircraftStateBusReader.width+(1:AircraftStateBusReader.width)) );
                    obj.results_noisy(aidx).north_ft = ownNoisyState.n_ft;
                    obj.results_noisy(aidx).east_ft = ownNoisyState.e_ft;
                    obj.results_noisy(aidx).up_ft = ownNoisyState.h_ft;
                    obj.results_noisy(aidx).speed_ftps = ownNoisyState.v_ftps;
                    obj.results_noisy(aidx).psi_rad = ownNoisyState.psi_rad;
                    obj.results_noisy(aidx).theta_rad = ownNoisyState.theta_rad;
                    obj.results_noisy(aidx).phi_rad = ownNoisyState.phi_rad;
                    obj.results_noisy(aidx).vertical_speed_ftps = ownNoisyState.dh_ftps;
                    obj.results_noisy(aidx).hdd_ftps2 = ownNoisyState.ddh_ftps2;
                    obj.results_noisy(aidx).latitude_rad = ownNoisyState.latLonAltState.lat_rad;
                    obj.results_noisy(aidx).longitude_rad = ownNoisyState.latLonAltState.lon_rad;
                    obj.results_noisy(aidx).altitude_ft = ownNoisyState.latLonAltState.alt_ft;
                    obj.results_noisy(aidx).dLatitude_radps = ownNoisyState.latLonAltState.dlat_radps;
                    obj.results_noisy(aidx).dLongitude_radps = ownNoisyState.latLonAltState.dlon_radps;
                    obj.results_noisy(aidx).dAltitude_ftps = ownNoisyState.latLonAltState.dalt_ftps;              

                    %%%%%% Ownship State Rates %%%%%%
                    varNames = fields( ownStateRate );
                    for k = 1 : numel(varNames),
                       obj.results_noisy(aidx).(varNames{k}) = acStateRate.(varNames{k});
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                elseif aidx ==2
              
                    obj.results_noisy(aidx).north_ft = intruderState.n_ft;
                    obj.results_noisy(aidx).east_ft = intruderState.e_ft;
                    obj.results_noisy(aidx).up_ft = intruderState.h_ft;
                    obj.results_noisy(aidx).speed_ftps = intruderState.v_ftps;
                    obj.results_noisy(aidx).vertical_speed_ftps = intruderState.hdot_ftps;
                    obj.results_noisy(aidx).Ndot_ftps = intruderState.Ndot_ftps;
                    obj.results_noisy(aidx).Edot_ftps = intruderState.Edot_ftps;
                    obj.results_noisy(aidx).hdot_ftps = intruderState.hdot_ftps;
    

%                     obj.results_noisy(aidx).psi_rad = intruderState.psi_rad;
%                     obj.results_noisy(aidx).theta_rad = intruderState.theta_rad;
%                     obj.results_noisy(aidx).phi_rad = intruderState.phi_rad;
%                     obj.results_noisy(aidx).vertical_speed_ftps = intruderState.dh_ftps;
%                     obj.results_noisy(aidx).hdd_ftps2 = ownNoisyState.ddh_ftps2;
%                     obj.results_noisy(aidx).latitude_rad = ownNoisyState.latLonAltState.lat_rad;
%                     obj.results_noisy(aidx).longitude_rad = ownNoisyState.latLonAltState.lon_rad;
%                     obj.results_noisy(aidx).altitude_ft = ownNoisyState.latLonAltState.alt_ft;
%                     obj.results_noisy(aidx).dLatitude_radps = ownNoisyState.latLonAltState.dlat_radps;
%                     obj.results_noisy(aidx).dLongitude_radps = ownNoisyState.latLonAltState.dlon_radps;
                    
                end
            end


            
            %%%  End of Modification Lines %%%
            % Pull out AvoidFlag (when anything was alerting) if present
            try
                if ~obj.isNominal
                    avoidFlag = obj.getSimulationOutput( 'AvoidFlag' );
                    assert( size(avoidFlag,2) == numAircraft );
                    for aidx = 1 : numAircraft
                        obj.results(aidx).AvoidFlag = avoidFlag(:,aidx);
                    end
                else
                    for aidx = 1 : numAircraft
                        obj.results(aidx).AvoidFlag = [];
                    end
                end
            end

            % If this was a simulation of the nominal trajectory,
            % store as such
            if( obj.isNominal() )
                obj.results_nominal = obj.results;
            end           
            
            % Generate warnings
            obj.warnings.checkEncounter(obj)
            
        end
    end
    
    
    %% Visualization Methods
    properties
       plottype = 'none'; % Indicates to method plot() what should be produced 
                          % 'sepfigs' generates separate figures.
    end    
    
    methods
        function plotPlanView(obj)            
        % Plan View (E vs. N)
        
            % CPA
            t = obj.results(1).time;
            tcpa = obj.outcome.tca;
            tcpa_i = find( t == tcpa );
        
            hold on
            plot(  obj.results_nominal(1).east_ft,  obj.results_nominal(1).north_ft, 'Color', [.5 .5 .5], 'LineStyle', ':' );    % aircraft 1
            plot(  obj.results_nominal(2).east_ft,  obj.results_nominal(2).north_ft, 'Color', [.4 .8  1], 'LineStyle', ':' );    % aircraft 2

            plot(  obj.results(1).east_ft, obj.results(1).north_ft,'k');   % aircraft 1
            plot(  obj.results(2).east_ft, obj.results(2).north_ft,'b--'); % aircraft 2
            plot(  obj.results(1).east_ft(tcpa_i), obj.results(1).north_ft(tcpa_i),'ko');
            plot(  obj.results(2).east_ft(tcpa_i), obj.results(2).north_ft(tcpa_i),'bo');
            plot(  obj.results(1).east_ft(1),      obj.results(1).north_ft(1),     'kx');
            plot(  obj.results(2).east_ft(1),      obj.results(2).north_ft(1),     'bx');
            axis( 'equal');
            xlabel( 'East (ft)');
            ylabel( 'North (ft)');

            rot1 = atan2( obj.results(1).north_ft(2) - obj.results(1).north_ft(1) , ...
                obj.results(1).east_ft(2)  - obj.results(1).east_ft(1) );
            text( obj.results(1).east_ft(1), obj.results(1).north_ft(1) , '\rightarrow' , ...
                'Rotation', DEGAS.rad2deg*rot1 );

            rot2 = atan2( obj.results(2).north_ft(2) - obj.results(2).north_ft(1) , ...
                obj.results(2).east_ft(2)  - obj.results(2).east_ft(1) );
            text( obj.results(2).east_ft(1), obj.results(2).north_ft(1) , '{\color{blue} \rightarrow}' , ...
                'Rotation', DEGAS.rad2deg*rot2  );
        
        end
        
     function plot(obj)      
        %% set up figures to be drawn
        hPlot = zeros(5,1);
        if ( strcmp(obj.plottype, 'sepfigs') || strcmp( obj.plottype, 'sepfigs_visacq' ) )
            figure; axis; hPlot(1) = gca;  hold on;    % vertical speed vs. time
            figure; axis; hPlot(2) = gca;  hold on;    % altitude vs. time
            figure; axis; hPlot(3) = gca;  hold on;    % E vs. N
            figure; axis; hPlot(4) = gca;  hold on;    % airspeed vs. time
            figure; axis; hPlot(5) = gca;  hold on;    % vertical acceleration (g)
%             figure; axis; hPlot(6) = gca;  hold on;    % altitude vs. time focused around tca
        else
            figure
            hold on
            hPlot(1) = subplot(2,3,1);  hold on;    % vertical speed vs. time
            hPlot(2) = subplot(2,3,2);  hold on;    % altitude vs. time
            hPlot(3) = subplot(2,3,3);  hold on;    % E vs. N
            hPlot(4) = subplot(2,2,3);  hold on;    % airspeed vs. time
            hPlot(5) = subplot(2,2,4);  hold on;    % vertical acceleration (g)
%             hPlot(6) = subplot(2,3,6);  hold on;    % altitude vs. time focused around tca
        end

        % CPA
        t = obj.results(1).time;
        if isempty(t)
            t = obj.simOut.get('tout');
        end
        tcpa = obj.outcome.tca;
        tcpa_i = find( t == tcpa );
        
        isNominal = obj.isNominal;

        %% vertical speed (ft/min) vs. time

        if isNominal
            hOpenLoop = zeros(12,1);
            t_openloop = obj.results_nominal(1).time;
            hOpenLoop(1) = plot(hPlot(2), t_openloop, obj.results_nominal(1).vertical_speed_ftps*(1/DEGAS.sec2min), 'Color', [.5 .5 .5], 'LineStyle', ':' );    % aircraft 1
            hOpenLoop(2) = plot(hPlot(2), t_openloop, obj.results_nominal(2).vertical_speed_ftps*(1/DEGAS.sec2min), 'Color', [.4 .8  1], 'LineStyle', ':' );    % aircraft 2
        end


        plot(hPlot(2), t, obj.results(1).vertical_speed_ftps*(1/DEGAS.sec2min),'k');    % aircraft 1
        plot(hPlot(2), t, obj.results(2).vertical_speed_ftps*(1/DEGAS.sec2min),'b--');    % aircraft 2

        xlabel(hPlot(2), 'Time (s)');
        ylabel(hPlot(2), 'Vertical Speed (ft/min)');
        set(hPlot(2), 'Ylim', [-4000 4000]);
        title(hPlot(2),'Vertical Speed vs. time');
        
        %% altitude (ft) vs. time
        min_alt = min( [obj.results(1).up_ft; obj.results(2).up_ft] );
        max_alt = max( [obj.results(1).up_ft; obj.results(2).up_ft] );
        d_alt = max_alt - min_alt;
        min_alt = min_alt - d_alt;
        max_alt = max_alt + d_alt;

        
        plot(hPlot(3), t, obj.results(1).up_ft,'k');      % aircraft 1
        plot(hPlot(3), t, obj.results(2).up_ft,'b--');      % aircraft 2                
        
        set(0, 'DefaultLegendAutoUpdate', 'off');
        
        if isNominal
            hOpenLoop(3) = plot(hPlot(3), t_openloop, obj.results_nominal(1).up_ft, 'Color', [.5 .5 .5], 'LineStyle', ':' );    % aircraft 1
            hOpenLoop(4) = plot(hPlot(3), t_openloop, obj.results_nominal(2).up_ft, 'Color', [.4 .8  1], 'LineStyle', ':' );    % aircraft 2
        end

        xlabel(hPlot(3), 'Time (s)');
        ylabel(hPlot(3), 'Altitude (ft)');
        line([tcpa tcpa],[min_alt max_alt],'LineStyle','--','Color','g' ,...
            'Parent', hPlot(3) );
        text( tcpa, max_alt, ' {\color{green} TCA}', ...
            'HorizontalAlignment','Left','VerticalAlignment','Top' , ...
            'Parent', hPlot(3) );

        vert_align = {'Top'; 'Bottom'};
        if obj.results(1).up_ft(1) >= obj.results(1).up_ft(2)
            v1 = vert_align{2};   v2 = vert_align{1};
        else
            v1 = vert_align{1};   v2 = vert_align{2};
        end
        text( t(1), obj.results(1).up_ft(1), '\rightarrow',  ...
            'HorizontalAlignment','Left','VerticalAlignment',v1, ...
            'Parent', hPlot(3) )

        text( t(1), obj.results(2).up_ft(1), '{\color{blue} \rightarrow}',  ...
            'HorizontalAlignment','Left','VerticalAlignment',v2, ...
            'Parent', hPlot(3) )

        title(hPlot(3),'Altitude vs. time');
        %% Plan View (E vs. N)

        if isNominal
            hOpenLoop(5) = plot(hPlot(1), obj.results_nominal(1).east_ft,  obj.results_nominal(1).north_ft, 'Color', [.5 .5 .5], 'LineStyle', ':' );    % aircraft 1
            hOpenLoop(6) = plot(hPlot(1), obj.results_nominal(2).east_ft,  obj.results_nominal(2).north_ft, 'Color', [.4 .8  1], 'LineStyle', ':' );    % aircraft 2
        end


        plot(hPlot(1), obj.results(1).east_ft, obj.results(1).north_ft,'k');   % aircraft 1
        plot(hPlot(1), obj.results(2).east_ft, obj.results(2).north_ft,'b--'); % aircraft 2
        plot(hPlot(1), obj.results(1).east_ft(tcpa_i), obj.results(1).north_ft(tcpa_i),'ko');
        plot(hPlot(1), obj.results(2).east_ft(tcpa_i), obj.results(2).north_ft(tcpa_i),'bo');
        plot(hPlot(1), obj.results(1).east_ft(1),      obj.results(1).north_ft(1),     'kx');
        plot(hPlot(1), obj.results(2).east_ft(1),      obj.results(2).north_ft(1),     'bx');
        axis(hPlot(1), 'equal');
        xlabel(hPlot(1), 'East (ft)');
        ylabel(hPlot(1), 'North (ft)');

        rot1 = atan2( obj.results(1).north_ft(2) - obj.results(1).north_ft(1) , ...
            obj.results(1).east_ft(2)  - obj.results(1).east_ft(1) );
        text( obj.results(1).east_ft(1), obj.results(1).north_ft(1) , '\rightarrow' , ...
            'Rotation', DEGAS.rad2deg*rot1, 'Parent', hPlot(1) );

        rot2 = atan2( obj.results(2).north_ft(2) - obj.results(2).north_ft(1) , ...
            obj.results(2).east_ft(2)  - obj.results(2).east_ft(1) );
        text( obj.results(2).east_ft(1), obj.results(2).north_ft(1) , '{\color{blue} \rightarrow}' , ...
            'Rotation', DEGAS.rad2deg*rot2, 'Parent', hPlot(1) );

        title(hPlot(1),'Plan View (East vs. North)');
        %% airspeed vs. time

        if isNominal
            hOpenLoop(7) = plot(hPlot(4), t_openloop, obj.results_nominal(1).speed_ftps*DEGAS.ftps2kt, 'Color', [.5 .5 .5], 'LineStyle', ':' );    % aircraft 1
            hOpenLoop(8) = plot(hPlot(4), t_openloop, obj.results_nominal(2).speed_ftps*DEGAS.ftps2kt, 'Color', [.4 .8  1], 'LineStyle', ':' );    % aircraft 2
        end

        plot(hPlot(4), t, obj.results(1).speed_ftps*DEGAS.ftps2kt,'k');
        plot(hPlot(4), t, obj.results(2).speed_ftps*DEGAS.ftps2kt,'b--');
        xlabel(hPlot(4), 'Time (s)');
        ylabel(hPlot(4), 'Airspeed (kt)');
        title(hPlot(4),'Airspeed vs. time');
        %% vertical acceleration

        plot(hPlot(5), t, obj.results(1).hdd_ftps2/DEGAS.g,'k');
        plot(hPlot(5), t, obj.results(2).hdd_ftps2/DEGAS.g,'b--');        
        
        if isNominal
            hOpenLoop(9) = plot(hPlot(5), t_openloop, obj.results_nominal(1).hdd_ftps2/DEGAS.g, 'Color', [.5 .5 .5], 'LineStyle', ':' );    % aircraft 1
            hOpenLoop(10) = plot(hPlot(5), t_openloop, obj.results_nominal(2).hdd_ftps2/DEGAS.g, 'Color', [.4 .8  1], 'LineStyle', ':' );    % aircraft 2
        end

        xlabel(hPlot(5), 'Time (s)');
        ylabel(hPlot(5), 'Vertical Acceleration (g)');

        title(hPlot(5),'Vertical Acceleration vs. time');
        legend(hPlot(5),{'Ownship','Intruder'},'Location','best');
%         %% specialized altitude focused at TCA
% 
% 
%         if isNominal
%             hOpenLoop(11) = plot(hPlot(2), t_openloop-tcpa,        obj.results_nominal(1).up_ft, 'Color', [.5 .5 .5], 'LineStyle', ':' );    % aircraft 1
%             hOpenLoop(12) = plot(hPlot(2), t_openloop+tcpa-t(end), flipud(obj.results_nominal(2).up_ft), 'Color', [.4 .8  1], 'LineStyle', ':' );    % aircraft 2
%         end
% 
%         plot(hPlot(2), t-tcpa, obj.results(1).up_ft,'k');      % aircraft 1
%         plot(hPlot(2), t(1)-tcpa, obj.results(1).up_ft(1),'kx');
%         % flip aircraft #2
%         ac2 = flipud(obj.results(2).up_ft);
%         plot(hPlot(2), t+tcpa-t(end), ac2,'b--');
%         plot(hPlot(2), t(end)+tcpa-t(end), ac2(end),'bx');
% 
%         text( t(1)-tcpa, obj.results(1).up_ft(1), '\rightarrow',  ...
%             'HorizontalAlignment','Left','VerticalAlignment','Top', ...
%             'Parent', hPlot(2) )
% 
%         text( t(end)+tcpa-t(end), ac2(end), '{\color{blue} \leftarrow}',  ...
%             'HorizontalAlignment','Right','VerticalAlignment','Top', ...
%             'Parent', hPlot(2) )
% 
% 
%         % shift aircraft #2 by (end-tcpa) and plot
% 
%         xlabel(hPlot(2), 'Time (s)');
%         ylabel(hPlot(2), 'Altitude (ft)');
%         line([0 0],[min_alt max_alt],'LineStyle','--','Color','g' , ...
%             'Parent', hPlot(2) );
%         text( 0, max_alt, ' {\color{green} TCA}', ...
%             'HorizontalAlignment','Left','VerticalAlignment','Top' , ...
%             'Parent', hPlot(2) )
% 
%         title(hPlot(2), {['VMD = ' num2str(round(obj.outcome.vmd_ft)) ' ft, HMD = ' ...
%             num2str(round(obj.outcome.hmd_ft)) ' ft, NMAC = ' num2str(obj.outcome.nmac,2)],'TCA focused altitude plot'} );

        %%% Modificatoin %%%
%         figure; axis;
%         plot(t, obj.results_noisy(1).vertical_speed_ftps*(1/DEGAS.sec2min),'k');    % aircraft 1
%         plot(t, obj.results(2).vertical_speed_ftps*(1/DEGAS.sec2min),'b--');    % aircraft 2
% 
%         xlabel('Time (s)');
%         ylabel('Noisy Vertical Speed (ft/min)');
% %         set('Ylim', [-4000 4000]);
%         title('Vertical Speed vs. time');
        %%%%%%%%%%%
    
%         figure; axis;
%         plot( t, obj.results_noisy(1).speed_ftps*DEGAS.ftps2kt,'k');
%         xlabel('Time (s)');
%         ylabel('Noisy Airspeed (kt)');
%         title('Noisy Airspeed vs. time');

          


        %%%%% End of Modification %%%
        
        end % End plot function   

     function plot_radar(obj)
             
        %% set up figures to be drawn
        hPlot = zeros(6,1);
        if ( strcmp(obj.plottype, 'sepfigs') || strcmp( obj.plottype, 'sepfigs_visacq' ) )
            figure; axis; hPlot(1) = gca;  hold on;    % vertical speed vs. time
            figure; axis; hPlot(2) = gca;  hold on;    % altitude vs. time
            figure; axis; hPlot(3) = gca;  hold on;    % E vs. N
            figure; axis; hPlot(4) = gca;  hold on;    % airspeed vs. time
            figure; axis; hPlot(5) = gca;  hold on;    % airspeed vs. time
          
        else
            figure
            hold on
            hPlot(1) = subplot(2,3,1);  hold on;    % vertical speed vs. time
            hPlot(2) = subplot(2,3,2);  hold on;    % altitude vs. time
            hPlot(3) = subplot(2,3,3);  hold on;    % E vs. N
            hPlot(4) = subplot(2,3,4);  hold on;    % airspeed vs. time
            hPlot(5) = subplot(2,3,5);  hold on; 
            hPlot(6) = subplot(2,3,6);  hold on; % airspeed vs. time
         
        end

        % CPA
        t = obj.results_radar.time;
        if isempty(t)
            t = obj.simOut.get('tout');
        end
        tcpa = obj.outcome.tca;
        tcpa_i = find( t == tcpa );
        

        %% Range (ft) vs. time
        plot(hPlot(1), t, obj.results_radar.range_ft,'r'); 
        xlabel(hPlot(1), 'Time (s)');
        ylabel(hPlot(1), 'Range (ft)');
        title(hPlot(1),'Range vs. time');

        %% azimuth_rad (rad) vs. time
        plot(hPlot(2), t, obj.results_radar.azimuth_rad,'r'); 
        xlabel(hPlot(2), 'Time (s)');
        ylabel(hPlot(2), 'Azimuth Angle (rad)');
        title(hPlot(2),'Azimuth Angle vs. time');

        %% elevation_rad (rad) vs. time
        plot(hPlot(3), t, obj.results_radar.elevation_rad,'r'); 
        xlabel(hPlot(3), 'Time (s)');
        ylabel(hPlot(3), 'Elevation Angle (rad)');
        title(hPlot(3),'Elevation Angle vs. time');

        %% Range Rate (ft/sec) vs. time
        plot(hPlot(4), t, obj.results_radar.range_dot,'r'); 
        xlabel(hPlot(4), 'Time (s)');
        ylabel(hPlot(4), 'Range Rate (ft)');
        title(hPlot(4),'Rate of change of Range vs. time');

        %% Range Rate (ft/sec) vs. time
        plot(hPlot(5), t, obj.results_radar.azdot_radps,'r'); 
        xlabel(hPlot(5), 'Time (s)');
        ylabel(hPlot(5), 'Azimuth Angle Rate (rad/s)');
        title(hPlot(5),'Rate of change of Azimuth Angle vs. time');
        %% Range Rate (ft/sec) vs. time
        plot(hPlot(6), t, obj.results_radar.eldot_radps,'r'); 
        xlabel(hPlot(6), 'Time (s)');
        ylabel(hPlot(6), 'Elevation Rate (rad/s)');
        title(hPlot(6),'Elevation Rate vs. time');
     end
     function plot_noisy(obj)      
        %% set up figures to be drawn
        hPlot = zeros(5,1);
        if ( strcmp(obj.plottype, 'sepfigs') || strcmp( obj.plottype, 'sepfigs_visacq' ) )
            figure; axis; hPlot(1) = gca;  hold on;    % vertical speed vs. time
            figure; axis; hPlot(2) = gca;  hold on;    % altitude vs. time
            figure; axis; hPlot(3) = gca;  hold on;    % E vs. N
            figure; axis; hPlot(4) = gca;  hold on;    % airspeed vs. time
            figure; axis; hPlot(5) = gca;  hold on;    % airspeed vs. time
          
        else
            figure
            hold on
            hPlot(1) = subplot(2,3,1);  hold on;    % vertical speed vs. time
            hPlot(2) = subplot(2,3,2);  hold on;    % altitude vs. time
            hPlot(3) = subplot(2,3,3);  hold on;    % E vs. N
            hPlot(4) = subplot(2,2,3);  hold on;    % airspeed vs. time
            hPlot(5) = subplot(2,2,4);  hold on;    % airspeed vs. time
         
        end

        % CPA
        t = obj.results_noisy(1).time;
        if isempty(t)
            t = obj.simOut.get('tout');
        end
        tcpa = obj.outcome.tca;
        tcpa_i = find( t == tcpa );
        

        %% vertical speed (ft/min) vs. time


        plot(hPlot(4), t, obj.results_noisy(2).vertical_speed_ftps*(1/DEGAS.sec2min),'r'); 
%         plot(hPlot(4), t, obj.results(1).vertical_speed_ftps*(1/DEGAS.sec2min),'k');% aircraft 1
        plot(hPlot(4), t, obj.results(2).vertical_speed_ftps*(1/DEGAS.sec2min),'b--');    % aircraft 2

        xlabel(hPlot(4), 'Time (s)');
        ylabel(hPlot(4), 'Vertical Speed (ft/min)');
%         set(hPlot(4), 'Ylim', [-4000 4000]);
        title(hPlot(4),'Vertical Speed vs. time');
        
        %% altitude (ft) vs. time
%         min_alt = min( [obj.results_noisy(2).up_ft; obj.results(2).up_ft] );
%         max_alt = max( [obj.results_noisy(2).up_ft; obj.results(2).up_ft] );
%         d_alt = max_alt - min_alt;
%         min_alt = min_alt - d_alt;
%         max_alt = max_alt + d_alt;

        
        plot(hPlot(3), t, obj.results_noisy(2).up_ft,'r'); 
%          plot(hPlot(3), t, obj.results(1).up_ft,'k'); % aircraft 1
        plot(hPlot(3), t, obj.results(2).up_ft,'b--');      % aircraft 2                
        
        set(0, 'DefaultLegendAutoUpdate', 'off');
       

        xlabel(hPlot(3), 'Time (s)');
        ylabel(hPlot(3), 'Altitude (ft)');
%         line([tcpa tcpa],[min_alt max_alt],'LineStyle','--','Color','g' ,...
%             'Parent', hPlot(3) );
%         text( tcpa, max_alt, ' {\color{green} TCA}', ...
%             'HorizontalAlignment','Left','VerticalAlignment','Top' , ...
%             'Parent', hPlot(3) );
% 
%         vert_align = {'Top'; 'Bottom'};
%         if obj.results_noisy(1).up_ft(1) >= obj.results_noisy(1).up_ft(2)
%             v1 = vert_align{2};   v2 = vert_align{1};
%         else
%             v1 = vert_align{1};   v2 = vert_align{2};
%         end
%         text( t(1), obj.results_noisy(1).up_ft(1), '\rightarrow',  ...
%             'HorizontalAlignment','Left','VerticalAlignment',v1, ...
%             'Parent', hPlot(3) )
% 
%         text( t(1), obj.results(2).up_ft(1), '{\color{blue} \rightarrow}',  ...
%             'HorizontalAlignment','Left','VerticalAlignment',v2, ...
%             'Parent', hPlot(3) )

        title(hPlot(3),'Altitude vs. time');
        %% Plan View (E vs. N)


        plot(hPlot(1), obj.results_noisy(2).east_ft, obj.results_noisy(1).north_ft,'r');   % aircraft 1
        plot(hPlot(1), obj.results(2).east_ft, obj.results(2).north_ft,'b--'); % aircraft 2
        plot(hPlot(1), obj.results_noisy(2).east_ft(tcpa_i), obj.results_noisy(1).north_ft(tcpa_i),'ro');
        plot(hPlot(1), obj.results(2).east_ft(tcpa_i), obj.results(2).north_ft(tcpa_i),'bo');
        plot(hPlot(1), obj.results_noisy(2).east_ft(1),      obj.results_noisy(1).north_ft(1),     'rx');
        plot(hPlot(1), obj.results(2).east_ft(1),      obj.results(2).north_ft(1),     'bx');

%         plot(hPlot(1), obj.results_noisy(1).east_ft, obj.results(1).north_ft,'k');   % aircraft 1   
%         plot(hPlot(1), obj.results_noisy(1).east_ft(tcpa_i), obj.results(1).north_ft(tcpa_i),'ko');
%         plot(hPlot(1), obj.results_noisy(1).east_ft(1),      obj.results(1).north_ft(1),     'kx');

        axis(hPlot(1), 'equal');
        xlabel(hPlot(1), 'East (ft)');
        ylabel(hPlot(1), 'North (ft)');

        rot1 = atan2( obj.results_noisy(1).north_ft(2) - obj.results_noisy(1).north_ft(1) , ...
            obj.results_noisy(1).east_ft(2)  - obj.results_noisy(1).east_ft(1) );
        text( obj.results_noisy(1).east_ft(1), obj.results_noisy(1).north_ft(1) , '\rightarrow' , ...
            'Rotation', DEGAS.rad2deg*rot1, 'Parent', hPlot(1) );

        rot2 = atan2( obj.results(2).north_ft(2) - obj.results(2).north_ft(1) , ...
            obj.results(2).east_ft(2)  - obj.results(2).east_ft(1) );
        text( obj.results(2).east_ft(1), obj.results(2).north_ft(1) , '{\color{blue} \rightarrow}' , ...
            'Rotation', DEGAS.rad2deg*rot2, 'Parent', hPlot(1) );

        title(hPlot(1),'Plan View (East vs. North)');
        %% airspeed vs. time

        plot(hPlot(2), t, obj.results_noisy(2).speed_ftps*DEGAS.ftps2kt,'r');
%         plot(hPlot(2), t, obj.results(1).speed_ftps*DEGAS.ftps2kt,'k');
        plot(hPlot(2), t, obj.results(2).speed_ftps*DEGAS.ftps2kt,'b--');
        xlabel(hPlot(2), 'Time (s)');
        ylabel(hPlot(2), 'Airspeed (kt)');
        title(hPlot(2),'Airspeed vs. time');


                %% vertical acceleration

        plot(hPlot(5), t, obj.results(1).hdd_ftps2/DEGAS.g,'k');
        plot(hPlot(5), t, obj.results_noisy(1).hdd_ftps2/DEGAS.g,'r');
        plot(hPlot(5), t, obj.results(2).hdd_ftps2/DEGAS.g,'b--');        
        

        xlabel(hPlot(5), 'Time (s)');
        ylabel(hPlot(5), 'Vertical Acceleration (g)');

        title(hPlot(5),'Vertical Acceleration vs. time');
        legend(hPlot(5),{'Ownship','Intruder'},'Location','best');

     end
     function visualize_data(obj, results_combined)
        figure
          %% airspeed vs. time
        t = obj.results_noisy(1).time;
        radar_states = obj.getSimulationOutput('RadarNoisyStates');
        plot( t, radar_states,'r');
%         plot( t, obj.results(1).speed_ftps*DEGAS.ftps2kt,'k');
%         plot( t, obj.radar_states(2).speed_ftps*DEGAS.ftps2kt,'b--');
        xlabel( 'Time (s)');
        ylabel( 'Range (kt)');
        title('Range vs. time');
%             hold on
%             hPlot(1) = subplot(1,3,1);  hold on;    % vertical speed vs. time
%             hPlot(2) = subplot(1,3,2);  hold on;    % altitude vs. time
%             hPlot(3) = subplot(1,3,3);  hold on;    % E vs. N
% %             hPlot(4) = subplot(2,2,3);  hold on;    % airspeed vs. time
% %             hPlot(5) = subplot(2,2,4);  hold on;    % airspeed vs. time
%         t = results_combined.time;
%         
% % 
% %         plot(hPlot(1), t, obj.results(1).latitude_rad,'b');
% %         plot(hPlot(1), t, results_combined.latitude_rad,'r--');
% %         xlabel(hPlot(1), 'Time (s)');
% %         ylabel(hPlot(1), 'Latitude (rad)');
% %         title(hPlot(1),'Latitude Position View vs. time');
% %      %--------------------------------------------------%
% %         
% %         plot(hPlot(2), t, obj.results(1).longitude_rad,'b');
% %         plot(hPlot(2), t, results_combined.longitude_rad,'r--');
% %         xlabel(hPlot(2), 'Time (s)');
% %         ylabel(hPlot(2), 'Longitude (rad)');
% %         title(hPlot(2),'Longitude Position View vs. time');
% 
% 
%         plot(hPlot(1), t, obj.results(1).Ndot_ftps*DEGAS.ftps2kt,'b');
%         plot(hPlot(1), t, results_combined.Ndot_ftps*DEGAS.ftps2kt,'r--');
%         xlabel(hPlot(1), 'Time (s)');
%         ylabel(hPlot(1), 'Speed in North (ft/s)');
%         title(hPlot(1),'North Rate vs. time');
%      %--------------------------------------------------%
%         
%         plot(hPlot(2), t, obj.results(1).Edot_ftps*DEGAS.ftps2kt,'b');
%         plot(hPlot(2), t, results_combined.Edot_ftps*DEGAS.ftps2kt,'r--');
%         xlabel(hPlot(2), 'Time (s)');
%         ylabel(hPlot(2), 'Speed in East (ft/s)');
%         title(hPlot(2),'East Rate vs. time');
%     %--------------------------------------------------%
%         plot(t, obj.results(1).speed_ftps*DEGAS.ftps2kt,'b');
%         plot(t, results_combined.speed_ftps*DEGAS.ftps2kt,'r--');
% 
%         xlabel('Time (s)');
%         ylabel('Airspeed (g)');
% 
%         title('Airspeed vs. time');
%         legend({'Ownship','Intruder'},'Location','best');
     end
     
     function resultsCombined =  injected_noisy_data(obj,encNum,combined_results, corrupted)
         
         obj.results_combined = repmat( obj.results(1), 2, 1 );
         variablesToRemove = {'AvoidFlag', 'hdd_ftps2', 'vdot_ftpss', 'dAltitude_ftps','psidot_radps', 'dLatitude_radps','dLongitude_radps','thetadot_radps','phidot_radps'};
         obj.results_combined = rmfield(obj.results_combined, variablesToRemove);
         obj.results_combined(1).label = repmat("clean", 901, 1);
         obj.results_noisy(1).label = repmat("noisy", 901, 1);
        
        if (corrupted)
        
             %%% Combine noisy data with clean data for Ownship %%%
                
          
             if (encNum > 0) && (encNum <= 25)
                 fieldNames = {'latitude_rad' ; 'longitude_rad'};
             elseif (encNum > 25) && (encNum <= 50)
                     fieldNames = {'altitude_ft'; 'up_ft'};
             elseif (encNum > 50) && (encNum <= 75)
                     fieldNames = {'Ndot_ftps'; 'Edot_ftps'; 'speed_ftps'}; %should we add hdot_ftps because airspeed also depends on it
             elseif (encNum > 75) && (encNum <= 100)
                     fieldNames = {'theta_rad'; 'phi_rad'};
             elseif (encNum > 100) && (encNum <= 111)
                     fieldNames = {'psi_rad'};       
             end
             
             len = length(fieldNames) + 1;
             fieldNames(len) = {'label'};
            
             rand_index1= randi([1,881]);
             rand_index2= rand_index1;
             while (rand_index2== rand_index1)
                 rand_index2 = randi([1,881]);
             end
             disp("rand_index1: ");
             disp(rand_index1)
            
             disp("rand_index2: ");
             disp(rand_index2)
            %% We have two batches of sequential data points that are being injected noisy values %%
            %% Each batch has 20 data points %%
             for i = 1:len
               %%% For Batch #1 ranging from rand_index1 to rand_index1+20    %%%
               obj.results_combined(1).(fieldNames{i})(rand_index1:rand_index1+19)  = obj.results_noisy(1).(fieldNames{i})(rand_index1:rand_index1+19); 
              
               %%% For Batch #2 ranging from rand_index2 to rand_index2+20    %%%
               obj.results_combined(1).(fieldNames{i})(rand_index2:rand_index2+19)  = obj.results_noisy(1).(fieldNames{i})(rand_index2:rand_index2+19);
               
             end 
         
        end
         %% Create combined result for all available encounter scripts
  
         tempResults = obj.results_combined(1);
         if isempty(fieldnames(combined_results))
             combined_results = tempResults;
             combined_results.encNum = repmat(encNum, 901, 1);
             
         else              
             tempResults.encNum = repmat(encNum, 901, 1);
             fields = fieldnames(tempResults);
             fieldLen = length(fields);
             
             %% Append this encounter script to the group of encounters %%
             for i = 1:fieldLen
                 combined_results.(string(fields(i))) = [combined_results.(string(fields(i))); tempResults(1).(string(fields(i)))];
             end
%               evalin('base','resultsCombined = combined_results');
             
         end
%          evalin('base','resultsCombined = combined_results');
            resultsCombined = combined_results;
           
     end

     
    end
end % End classdef