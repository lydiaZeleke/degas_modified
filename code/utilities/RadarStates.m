classdef RadarStates
% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: X11
%
% AircraftRadarStates: Used to interpret the output from a 
% AircraftState bus at the top level of a Simulink model

    properties(Constant=true,Access=private)
        busInfo = BusInformation( evalin('base','AircraftState') ); 
        % NOTE: evalin gets Simulink.Bus object from base workspace
    end
%     properties(Constant=true)
%         % The number of scalar values contained on the bus.  This is 
%         % generally not equal to the number of elements in the bus.  
%         width = 10;
%     end

    methods
        function this = RadarStates( signals )
        % Interpret a matrix as a flattened AircraftStateBus 
        % signals is an N x (AircraftRadarStates.width) double matrix of
        % outputs from an AircraftState bus
            
%             assert( size( signals, 2 ) == 11 );
            
            this.matrix_data_ = signals;
        end
    end
    
    properties(Access=private)
        matrix_data_
    end
    
    properties(Dependent = true)
       range_ft
       az_rad
       el_rad
       dRange_dtps
       rngVar_ft2
       azVar_rad2
       elVar_rad2
       dRngVar_ft2ps2
       isValid
       azdot_radps
       eldot_radps
      

    end
    
    methods
       
        function value = get.range_ft( this )
            value = this.matrix_data_(:,1);
        end
        function value = get.az_rad( this )
            value = this.matrix_data_(:,2);
        end
        function value = get.el_rad( this )
            value = this.matrix_data_(:,3);
        end
        function value =  get.dRange_dtps( this )
            value = this.matrix_data_(:,4);
        end
        function value = get.rngVar_ft2( this )
            value = this.matrix_data_(:,5);
        end
        function value =  get.azVar_rad2( this )
            value = this.matrix_data_(:,6);
        end 
        function value =  get.elVar_rad2( this )
            value = this.matrix_data_(:,7);
        end 
        function value =  get.dRngVar_ft2ps2( this )
            value = this.matrix_data_(:,8);
        end 
        function value =  get.azdot_radps( this )
            value = this.matrix_data_(:,10);
        end 
        function value =  get.eldot_radps( this )
            value = this.matrix_data_(:,11);
        end     
     
    end
    
end