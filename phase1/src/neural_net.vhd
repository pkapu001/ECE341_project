-- Use this activation function for every neuron in the network:
-- a(x) = 1 / (1 + e^(-X)) 

-- We need numbers like this: 01111111.11111111 
-- We need to at least account for numbers in the range of [-128, 128). This accounts for that and then some.

library ieee_proposed; 
use ieee_proposed.fixed_pkg.all;

package custom_types is
	type int_array is array (integer range <>) of integer range 0 to 255; -- array of variable length (of type integer)
	-- 20 is the max number of neurons that can be in a layer. 
	-- 21 is max_number_of_neurons_per_layer + bias (which is just 20 + 1)
	type inputs_array is array (0 to 19) of sfixed(7 downto -8); -- needs to account for values in range [-1, 1)
	type weights_array is array (integer range <>) of sfixed(7 downto -8); -- each neuron has an array of weights (variable number)
	type layer_matrix is array (0 to 19) of weights_array(0 to 20); -- each layer has a collection of neuron weights
	type neural_network is array (integer range <>) of layer_matrix; -- a neural network has a collection of layers	
end custom_types;

use custom_types.all;
library ieee_proposed; 
library ieee;
use ieee_proposed.fixed_pkg.all;  
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;		  

-- changes made : changed the number of layers in generic line: 34

entity model is	 
	generic(
		number_of_inputs : integer := 10;
		number_of_layers : integer := 2;  
		max_num_neurons_in_layer : integer := 20;
		number_of_neurons_per_layer : int_array(0 to 2) := (10, 10, 5); 		 -- first index represents the inputs (only 2 layers here)		
		number_of_weights_per_neuron_in_layer : int_array(0 to 1) := (11, 11); -- hardcoded for now
		sfixed_first : integer := 7;                                         -- 8 bits left of decimal point
		sfixed_second : integer := -8                                        -- 8 bits right of decimal point
	);
	port(
		LOAD : in std_logic;				                      -- active high (sychronous)
		INPUT : in inputs_array;                                  -- each bit is an input value (0 or 1 or X)   
		START : in std_logic;                                     -- active high (synchronous)
		hasStarted : buffer std_logic;                            -- indicates if the inference calculation has started
		CLK : in std_logic;	                                      -- rising-edge triggered clock 
		LOAD_LAYER : in layer_matrix;                             -- structure that holds all weights for a layer
		LOAD_LAYER_NUMBER : in std_logic_vector(0 to 3);          -- each binary value maps to a layer where 0000 is layer 1 (accounts for up to 16 layers)
		LOAD_DONE : out std_logic;                                -- active high (1 when load is finished)  
		DONE : buffer std_logic;                                  -- active high when inference is ready (OUTPUT is meaningful) This is a buffer so we can read it
		OUTPUT_1 : out sfixed(sfixed_first downto sfixed_second); -- The value (inference value). There will be up to 5 outputs in this model.
		OUTPUT_2 : out sfixed(sfixed_first downto sfixed_second); -- output 2
		OUTPUT_3 : out sfixed(sfixed_first downto sfixed_second); -- output 3
		OUTPUT_4 : out sfixed(sfixed_first downto sfixed_second); -- output 4
		OUTPUT_5 : out sfixed(sfixed_first downto sfixed_second)  -- output 5
	);
end entity model;	

architecture behavioral of model is		
	signal neural_network : neural_network(0 to number_of_layers-1 );
begin
	process	
	begin
		hasStarted <= '0'; -- initialize hasStarted to '0'
		wait;
	end process;
	
	process(LOAD, START, CLK)
		-- VARIABLES
		variable layer_index : integer;	-- used in conversion from std_logic_vector to integer (for LOAD_LAYER_NUMBER)
		variable x_value : sfixed(sfixed_first downto sfixed_second) := "0000000000000000"; -- used in the summation of weights for X (where X is in activation function)
		variable tmp_weights_array : weights_array(0 to max_num_neurons_in_layer); -- holds all the weights (including bias) for a neuron	
		variable tmp_layer_matrix : layer_matrix; -- holds all the collections of weights in a layer
		variable tmp_real : real;
		variable one_as_sfixed : sfixed(sfixed_first downto sfixed_second) := "0000000100000000"; -- 00000001.00000000	
		variable zero_as_sfixed : sfixed(sfixed_first downto sfixed_second) := "0000000000000000";
		variable single_neuron_output : sfixed(sfixed_first downto sfixed_second);
		variable neuron_outputs : weights_array(0 to max_num_neurons_in_layer - 1);	 -- storing the outputs (based on weights going into neuron and activation function).
		variable temp_neuron_outputs : weights_array(0 to max_num_neurons_in_layer - 1); -- storing the outputs (based on weights going into neuron and activation function).
		-- TODO: neuron_outputs is not actually storing weights, so maybe we should consider renaming the type.
		-- and also this is storing the weights for the previous layer so that we can keep track of what to multiply each incoming weight by for
		-- each neuron in the next layer.
		
	begin -- by this design, it doesn't matter if START or LOAD get changed asynchronously. The rising clock edge is the trigger.		
		if (CLK'event and CLK = '1') then 
			if (START = '1') then -- start has priority over load 
				LOAD_DONE <= '0';
				DONE <= '0'; -- we want to start a new inference. Reset DONE.
				if (hasStarted = '1') then -- already started, do nothing
					report "The inference calculation has already been started!" severity note;
				else -- has not started and we want to start. start it and do the calculations
					hasStarted <= '1';
		  			for i in 0 to number_of_layers - 1 loop -- loop through every layer in the network
						tmp_layer_matrix := neural_network(i); 
						
						if (i = 0) then
							for x in 0 to max_num_neurons_in_layer - 1 loop
								neuron_outputs(x) := INPUT(x);
								--report "The INPUT AT " & integer'image(x) & " : " & real'image(to_real(INPUT(x))) severity error;
							end loop;
						end if;
						--for x in 0 to max_num_neurons_in_layer - 1 loop
						--	report "LAYER " & integer'image(i) & " - neuron_outputs(" & integer'image(x) & ") : " & real'image(to_real(neuron_outputs(x))) severity error;
						--end loop;
						
						for j in 0 to max_num_neurons_in_layer - 1 loop -- loop through every neuron's collection of weights. 20 is the maximum number of neurons per layer
							tmp_weights_array := tmp_layer_matrix(j);
							x_value := "0000000000000000"; 
							
						--	report "===== Neuron " & integer'image(j) & " in Layer " & integer'image(i) & " *** WEIGHTS WITH BIAS AT [0] =====" severity error;
						--	for w in 0 to 2 loop
						--		 report "tmp_weights_array[" & integer'image(w) & "] : " & real'image(to_real(tmp_weights_array(w))) severity error;
						--	end loop;
							report "--------------------------x-sum------------------" severity error;
							for k in 0 to number_of_neurons_per_layer(i)-1 loop -- loop through every weight in this neuron's collection of weights (excluding bias)
								report "LAYER " & integer'image(i) & " -neuron(" & integer'image(j) & ") weight["&integer'image(k) &"] : "& real'image(to_real(x_value)) & " + to_real(" & real'image(to_real(tmp_weights_array(k+1 )))&" * "&real'image(to_real(neuron_outputs( k ))) &")"&" neuraloutnut["&integer'image(k)&"]" &" = " & real'image( to_real( (tmp_weights_array(k+1) * neuron_outputs(k)) ) ) severity error;
								x_value := to_sfixed(to_real(x_value) + to_real((tmp_weights_array(k+1) * neuron_outputs(k))), sfixed_first, sfixed_second);
								--report "k=" & integer'image(k) & " : " & real'image(to_real(x_value)) severity error;
							end loop;	  
							report "--------------------------x-sum-end------------------" severity error;
							x_value := to_sfixed(to_real(x_value + tmp_weights_array(0)), sfixed_first, sfixed_second); -- add the bias
							report "layer " & integer'image(i) & " | neuron "& integer'image(j)& "with bias" &real'image(to_real(tmp_weights_array(0))) &" => x_value : " & real'image(to_real(x_value)) severity error;
							
							-- compute activation function for neural_network(i)(j) with x_value
							if (j < number_of_neurons_per_layer(i + 1)) then
								tmp_real := (to_real(one_as_sfixed) / (to_real(one_as_sfixed) + exp(to_real(zero_as_sfixed - x_value))));
								single_neuron_output := to_sfixed(tmp_real, sfixed_first, sfixed_second);
							else
								single_neuron_output := zero_as_sfixed;
							end if;
							temp_neuron_outputs(j) := single_neuron_output;
							
						end loop; 
						neuron_outputs := temp_neuron_outputs	;
						
						--for x in 0 to max_num_neurons_in_layer - 1 loop
						--	report "LAYER " & integer'image(i + 1) & " - neuron_outputs(" & integer'image(x) & ") : " & real'image(to_real(neuron_outputs(x))) severity error;
						--end loop;
					end loop;
					
					-- There are up to 5 outputs. If an output is 0, then it is considered to be unmeaningful
					-- The number of meaningful outputs depends on the number of neurons in the last layer
					-- If there are more than 5 neurons in the last layer, then only the first 5 will have outputs according to this design.
					OUTPUT_1 <= neuron_outputs(0);
					OUTPUT_2 <= neuron_outputs(1);
					OUTPUT_3 <= neuron_outputs(2);
					OUTPUT_4 <= neuron_outputs(3);
					OUTPUT_5 <= neuron_outputs(4);
					report "===== START OF A NEW INFERENCE =====" severity note;
					report "OUTPUT_1 : " & real'image(to_real(neuron_outputs(0))) severity error;
					report "OUTPUT_2 : " & real'image(to_real(neuron_outputs(1))) severity error;
					report "OUTPUT_3 : " & real'image(to_real(neuron_outputs(2))) severity error;
					report "OUTPUT_4 : " & real'image(to_real(neuron_outputs(3))) severity error;
					report "OUTPUT_5 : " & real'image(to_real(neuron_outputs(4))) severity error;
					DONE <= '1';
					
				end if;
			elsif (LOAD = '1') then -- we want to load a layer of weights into the network
				layer_index := to_integer(unsigned(LOAD_LAYER_NUMBER));
				neural_network(layer_index) <= LOAD_LAYER;
				LOAD_DONE <= '1';
				report "Loaded data into layer " & integer'image(layer_index + 1) & " of " & integer'image(number_of_layers) severity error;
			end if;
		end if;
	end process; 
	
	process(DONE)
	begin 
		if (DONE = '1') then -- finished making the inference
			hasStarted <= '0';
		elsif (DONE = '0') then -- DONE changed from something to 0. Do we need to do anything?
			--OUTPUT <= to_sfixed('U' , sfixed_first, sfixed_second);
		end if;
	end process;
	
end architecture behavioral;
