SetActiveLib -work
comp -include "$dsn\src\neural_net.vhd" 
comp -include "$dsn\src\TestBench\model_TB.vhd" 
asim +access +r TESTBENCH_FOR_model 
wave 
wave -noreg LOAD
wave -noreg INPUT
wave -noreg START
wave -noreg hasStarted
wave -noreg CLK
wave -noreg LOAD_LAYER
wave -noreg LOAD_LAYER_NUMBER
wave -noreg LOAD_DONE
wave -noreg DONE
wave -noreg OUTPUT_1
wave -noreg OUTPUT_2
wave -noreg OUTPUT_3
wave -noreg OUTPUT_4
wave -noreg OUTPUT_5
# The following lines can be used for timing simulation
# acom <backannotated_vhdl_file_name>
# comp -include "$dsn\src\TestBench\model_TB_tim_cfg.vhd" 
# asim +access +r TIMING_FOR_model 
