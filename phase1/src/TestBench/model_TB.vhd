library phase1;
use phase1.custom_types.all;
library ieee;
use ieee.MATH_REAL.all;
use ieee.STD_LOGIC_UNSIGNED.all;

-- Add your library and packages declaration here ...
use custom_types.all;
library ieee_proposed; 
library ieee;
use ieee_proposed.fixed_pkg.all;  
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

entity model_tb is
	-- Generic declarations of the tested unit
	generic(
		number_of_inputs : INTEGER := 10;
		number_of_layers : INTEGER := 2;
		max_num_neurons_in_layer : INTEGER := 20;
		number_of_neurons_per_layer : int_array(0 to 2) := (10, 10, 5);
		number_of_weights_per_neuron_in_layer : int_array(0 to 1) := (11, 6);
		sfixed_first : integer := 7;
		sfixed_second : integer := -8
	);
end model_tb;

architecture TB_ARCHITECTURE of model_tb is
	-- Component declaration of the tested unit
	component model
		generic(
			number_of_inputs : INTEGER := 10;
			number_of_layers : INTEGER := 2;
			max_num_neurons_in_layer : INTEGER := 20;
			number_of_neurons_per_layer : int_array(0 to 2);
			number_of_weights_per_neuron_in_layer : int_array(0 to 1);
			sfixed_first : integer := 7;
			sfixed_second : integer := -8
		);
	port(
			LOAD : in STD_LOGIC;
			INPUT : in inputs_array;
			START : in STD_LOGIC;
			hasStarted : buffer STD_LOGIC;
			CLK : in STD_LOGIC;
			LOAD_LAYER : in layer_matrix;
			LOAD_LAYER_NUMBER : in STD_LOGIC_VECTOR(0 to 3);
			LOAD_DONE : out STD_LOGIC;
			DONE : buffer STD_LOGIC;
			OUTPUT_1 : out sfixed(sfixed_first downto sfixed_second);
			OUTPUT_2 : out sfixed(sfixed_first downto sfixed_second);
			OUTPUT_3 : out sfixed(sfixed_first downto sfixed_second);
			OUTPUT_4 : out sfixed(sfixed_first downto sfixed_second);
			OUTPUT_5 : out sfixed(sfixed_first downto sfixed_second)
		);
	end component;

	-- Stimulus signals - signals mapped to the input and inout ports of tested entity
	signal LOAD : STD_LOGIC;
	signal INPUT : inputs_array;
	signal START : STD_LOGIC;
	signal CLK : STD_LOGIC;
	signal LOAD_LAYER : layer_matrix;
	signal LOAD_LAYER_NUMBER : STD_LOGIC_VECTOR(0 to 3);  
	
	-- Observed signals - signals mapped to the output ports of tested entity
	signal hasStarted : STD_LOGIC;
	signal LOAD_DONE : STD_LOGIC;
	signal DONE : STD_LOGIC;
	signal OUTPUT_1 : sfixed(sfixed_first downto sfixed_second);
	signal OUTPUT_2 : sfixed(sfixed_first downto sfixed_second);
	signal OUTPUT_3 : sfixed(sfixed_first downto sfixed_second);
	signal OUTPUT_4 : sfixed(sfixed_first downto sfixed_second);
	signal OUTPUT_5 : sfixed(sfixed_first downto sfixed_second);
	
	-- add additional signals/variables here ...
	signal clk_half_period : time := 100 ns; -- 200 ns clock period
	
begin

	UUT : model
		generic map (
			number_of_inputs => number_of_inputs,
			number_of_layers => number_of_layers,
			max_num_neurons_in_layer => max_num_neurons_in_layer,
			number_of_neurons_per_layer => number_of_neurons_per_layer,
			number_of_weights_per_neuron_in_layer => number_of_weights_per_neuron_in_layer,
			sfixed_first => sfixed_first,
			sfixed_second => sfixed_second
		)
		port map (
			LOAD => LOAD,
			INPUT => INPUT,
			START => START,
			hasStarted => hasStarted,
			CLK => CLK,
			LOAD_LAYER => LOAD_LAYER,
			LOAD_LAYER_NUMBER => LOAD_LAYER_NUMBER,
			LOAD_DONE => LOAD_DONE,
			DONE => DONE,
			OUTPUT_1 => OUTPUT_1,
			OUTPUT_2 => OUTPUT_2,
			OUTPUT_3 => OUTPUT_3,
			OUTPUT_4 => OUTPUT_4,
			OUTPUT_5 => OUTPUT_5
		);

	-- Add your stimulus here ...
	process
	begin  
		CLK <= '0'; wait for clk_half_period;
		CLK <= '1'; wait for clk_half_period;
	end process;
	
	-- Add test cases here ... 
	-- since the weights are slightly larger format than what we can account for, let's load this data:
	-- LAYER_1 = [
	--            [2.9531  -5.8151  5.9434], 
	--            [-2.9171  -5.5621  5.3736]
	--           ]
	-- LAYER_2 = [[3.9713  -8.4911  8.9247]] 
	
	-- so, we need to convert those values to sfixed (16 bits in the form of 111.1111111111111)
	-- LAYER_1 = [
	--            [00000010.11110011  11111010.00101111  00000101.11110001], 
	--            [11111101.00010101  11111010.01110000  00000101.01011111]
	--           ]
	-- LAYER_2 = [[00000011.11111000  11110111.10000010  00001000.11101100]]
	process
		variable layer_1_data : layer_matrix;
		variable layer_2_data : layer_matrix;
		variable tmp_weights_array_1 : weights_array(0 to max_num_neurons_in_layer);
		variable tmp_weights_array_2 : weights_array(0 to max_num_neurons_in_layer);
		variable empty_weights_array : weights_array(0 to max_num_neurons_in_layer);
	begin						  
		-- initialie the empty weights array
		for i in 0 to max_num_neurons_in_layer loop
			empty_weights_array(i) := to_sfixed(0, sfixed_first, sfixed_second); --"0000000000000000";
		end loop;  
		
		-- develop the first layer
		for i in 0 to max_num_neurons_in_layer-1 loop
			if(i mod 2 = 0) then
				layer_1_data(i)(0) := to_sfixed(2.9531, sfixed_first, sfixed_second);	  -- loading bias for later 1 neuron 0,2,4... first neuron of every xor
			else
				layer_1_data(i)(0) := to_sfixed(-2.9171, sfixed_first, sfixed_second);	  -- loading bias for later 1 neuron 1,3,5... second neuron of every xor			
			end if;
			for j in 1 to max_num_neurons_in_layer  loop 
				if(i mod 2 = 0 and i<10) then   
					
					
					if (i + 1 = j ) then
						layer_1_data(i)(j) := to_sfixed(-5.8151, sfixed_first, sfixed_second);
					elsif(i+ 2 = j) then
						layer_1_data(i)(j) := to_sfixed(5.9434, sfixed_first, sfixed_second);
					else
						layer_1_data(i)(j) := to_sfixed(0, sfixed_first, sfixed_second);
					end if;
									
				elsif (i<10) then
						if (i  = j ) then
							layer_1_data(i)(j) := to_sfixed(-5.5621, sfixed_first, sfixed_second);
						elsif(i+1 = j) then
							layer_1_data(i)(j) := to_sfixed(5.3736, sfixed_first, sfixed_second);
						else
							layer_1_data(i)(j) := to_sfixed(0, sfixed_first, sfixed_second);
						end if;
				else
					layer_1_data(i)(j) := to_sfixed(0, sfixed_first, sfixed_second);	
						
				end if;					
			end loop  ;
		end loop;

		
		-- develop the second layer
		for i in 0 to max_num_neurons_in_layer-1 loop
			 	layer_2_data(i)(0) := to_sfixed(3.9713, sfixed_first, sfixed_second);
			for j in 1 to max_num_neurons_in_layer loop	
				if(i<5) then
					if (i*2 +1 = j ) then
						layer_2_data(i)(j) := to_sfixed(-8.4911, sfixed_first, sfixed_second); --"0000001111111000";
					--elsif (i = 1) then
						--tmp_weights_array_1(i) := to_sfixed(-8.4911, sfixed_first, sfixed_second); --"1111011110000010"; 
						--report "-8.4911 => " & real'image(to_real(to_sfixed(-8.4911, sfixed_first, sfixed_second))) severity error;
					elsif ((i+1)*2 = j) then
						layer_2_data(i)(j) := to_sfixed(8.9247, sfixed_first, sfixed_second); --"0000100011101100";
					else 
						layer_2_data(i)(j) := to_sfixed(0, sfixed_first, sfixed_second); --"0000000000000000";
					end if;
				else
					layer_2_data(i)(j) := to_sfixed(0, sfixed_first, sfixed_second);
				end if;			
			end loop;
		end loop;
		for i in 0 to max_num_neurons_in_layer - 1 loop
			if (i = 0) then
				--layer_2_data(i) := tmp_weights_array_1;		
			else 
				--layer_2_data(i) := empty_weights_array;
			end if;
		end loop;
		
		-- we have our layers. Now load them into the network
		-- first, load layer 1
		wait for 90 ns;
		LOAD <= '1';
		LOAD_LAYER <= layer_1_data;
		LOAD_LAYER_NUMBER <= "0000";
		wait for clk_half_period * 2;
		
		-- now load layer 2	
		LOAD_LAYER <= layer_2_data;
		LOAD_LAYER_NUMBER <= "0001";
		wait for clk_half_period * 2;
		
		INPUT(0) <= to_sfixed(1, sfixed_first, sfixed_second);
		INPUT(1) <= to_sfixed(0, sfixed_first, sfixed_second);
		INPUT(2) <= to_sfixed(0, sfixed_first, sfixed_second);
		INPUT(3) <= to_sfixed(0, sfixed_first, sfixed_second);
		INPUT(4) <= to_sfixed(0, sfixed_first, sfixed_second);
		INPUT(5) <= to_sfixed(0, sfixed_first, sfixed_second);
		INPUT(6) <= to_sfixed(1, sfixed_first, sfixed_second);
		INPUT(7) <= to_sfixed(0, sfixed_first, sfixed_second);
		INPUT(8) <= to_sfixed(1, sfixed_first, sfixed_second);
		INPUT(9) <= to_sfixed(0, sfixed_first, sfixed_second);
		
		-- start the inference calculation... use 01 as the input
		-- get our input ready (1, 0) (plus an extra 18 0's)
		--for i in 0 to max_num_neurons_in_layer - 1 loop
		--	if (i = 0) then
			--	INPUT(i) <= to_sfixed(0, sfixed_first, sfixed_second); --"0000000000000000";	
			--elsif (i = 1) then
			--	INPUT(i) <= to_sfixed(0, sfixed_first, sfixed_second); --"0000000100000000";
			--else 
			--	INPUT(i) <= to_sfixed(0, sfixed_first, sfixed_second); --"0000000000000000";
			--end if;
		-- end loop; 
		-- start!
		LOAD <= '0';
		START <= '1';
		wait for 20 ns;
		START <= '0'; 
		
		-- now try 01
		--wait for 180 ns; -- clk_half_period * 2 - 20
		--for i in 0 to max_num_neurons_in_layer - 1 loop
		--	if (i = 0) then
		--		INPUT(i) <= "0000000000000000";	
		--	elsif (i = 1) then
		--		INPUT(i) <= "0000000100000000";
		--	else 
		--		INPUT(i) <= "0000000000000000";
		--	end if;
		--end loop;
		--START <= '1';
		--wait for 20 ns; 
		--START <= '0';
		
		wait;
	end process;
	

end TB_ARCHITECTURE;

configuration TESTBENCH_FOR_model of model_tb is
	for TB_ARCHITECTURE
		for UUT : model
			use entity work.model(behavioral);
		end for;
	end for;
end TESTBENCH_FOR_model;
