classdef AircraftRadarConvertedStates
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
        function this = AircraftRadarConvertedStates( signals )
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
        n_ft
        e_ft
        h_ft
        v_ftps
        Ndot_ftps
        Edot_ftps
        hdot_ftps
        latLonAltState
        psi_rad
        theta_rad
        phi_rad
        psidot_radps
        thetadot_radps
        phidot_radps
        dv_ftps2
        ddh_ftps2
%         p_radps
%         q_radps
%         r_radps       
%         dh_ftps
        
      

    end
    
    methods
       
        function value = get.n_ft( this )
            value = this.matrix_data_(:,1);
        end
        function value = get.e_ft( this )
            value = this.matrix_data_(:,2);
        end
        function value = get.h_ft( this )
            value = this.matrix_data_(:,3);
        end
        function value =  get.v_ftps( this )
            value = this.matrix_data_(:,4);
        end
        function value = get.Ndot_ftps( this )
            value = this.matrix_data_(:,5);
        end
        function value =  get.Edot_ftps( this )
            value = this.matrix_data_(:,6);
        end 
        function value =  get.hdot_ftps( this )
            value = this.matrix_data_(:,7);
        end 
%         function value =  get.latLonAltState( this )
%             value = this.matrix_data_(:,5);
%         end
        
%         function value = get.psi_rad( this )
%             value = this.matrix_data_(:,6);
%         end
%         function value = get.theta_rad( this )
%             value = this.matrix_data_(:,7);
%         end
%         function value = get.phi_rad( this )
%             value = this.matrix_data_(:,8);
%         end

%          function value = get.dv_ftps2( this )
%             value = this.matrix_data_(:,12);
%         end
%         function value = get.ddh_ftps2( this )
%             value = this.matrix_data_(:,14);
%         end        
     
    end
    
end