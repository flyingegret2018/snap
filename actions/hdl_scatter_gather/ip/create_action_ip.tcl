## Env Variables

set action_root [lindex $argv 0]
set fpga_part  	[lindex $argv 1]
puts "FPGACHIP = $fpga_part"
puts "ACTION_ROOT = $action_root"

set aip_dir 	$action_root/ip
set log_dir     $action_root/../../hardware/logs
set log_file    $log_dir/create_action_ip.log
set src_path 	$aip_dir/action_ip_prj/action_ip_prj.srcs

## Create a new Vivado IP Project
puts "\[CREATE_ACTION_IPs..........\] start [clock format [clock seconds] -format {%T %a %b %d %Y}]"
create_project action_ip_prj $aip_dir/action_ip_prj -force -part $fpga_part -ip

# Project IP Settings
# General
set_property target_language Verilog [current_project] >> $log_file


##################################################################################
##################################################################################
##################################################################################
puts "\[Generate User IP 1 (AFU_DMA)\]"
##################################################################################
#   Add afu_dma IPs
##################################################################################

puts "Generating fifo_512_64 ......"
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name fifo_512_64 >> $log_file 
set_property -dict [list CONFIG.Component_Name {fifo_512_64} CONFIG.Fifo_Implementation {Common_Clock_Block_RAM} CONFIG.Performance_Options {First_Word_Fall_Through} CONFIG.asymmetric_port_width {true} CONFIG.Input_Data_Width {512} CONFIG.Input_Depth {256} CONFIG.Output_Data_Width {64} CONFIG.Output_Depth {16384} CONFIG.Use_Embedded_Registers {false} CONFIG.Reset_Type {Asynchronous_Reset} CONFIG.Full_Flags_Reset_Value {1} CONFIG.Use_Extra_Logic {true} CONFIG.Data_Count_Width {12} CONFIG.Write_Data_Count_Width {12} CONFIG.Read_Data_Count_Width {15} CONFIG.Full_Threshold_Assert_Value {2045} CONFIG.Full_Threshold_Negate_Value {2044} CONFIG.Empty_Threshold_Assert_Value {4} CONFIG.Empty_Threshold_Negate_Value {5} CONFIG.Enable_Safety_Circuit {false}] [get_ips fifo_512_64] >> $log_file
generate_target all [get_files $src_path/sources_1/ip/fifo_512_64/fifo_512_64.xci] >> $log_file

puts "\[CREATE_ACTION_IPs..........\] done  [clock format [clock seconds] -format {%T %a %b %d %Y}]"
close_project
