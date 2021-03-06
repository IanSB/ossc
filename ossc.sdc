### CPU clock constraints ###

create_clock -period 27MHz -name clk27 [get_ports clk27]

set_input_delay -clock clk27 0 [get_ports {sda scl SD_CMD SD_DAT* *ALTERA_DATA0}]
set_false_path -from [get_ports {btn* ir_rx HDMI_TX_INT_N HDMI_TX_MODE}]
set_false_path -to {sys:sys_inst|sys_pio_1:pio_1|readdata*}


### Scanconverter clock constraints ###

create_clock -period 108MHz -name pclk_1x [get_ports PCLK_in]
create_clock -period 33MHz -name pclk_2x_source [get_ports PCLK_in] -add
create_clock -period 33MHz -name pclk_3x_source [get_ports PCLK_in] -add
create_clock -period 33MHz -name pclk_4x_source [get_ports PCLK_in] -add
create_clock -period 33MHz -name pclk_5x_source [get_ports PCLK_in] -add

#derive_pll_clocks
create_generated_clock -master_clock pclk_2x_source -source {scanconverter_inst|pll_linedouble|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 2 -duty_cycle 50.00 -name pclk_2x {scanconverter_inst|pll_linedouble|altpll_component|auto_generated|pll1|clk[0]}
create_generated_clock -master_clock pclk_3x_source -source {scanconverter_inst|pll_linetriple|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 3 -duty_cycle 50.00 -name pclk_3x {scanconverter_inst|pll_linetriple|altpll_component|auto_generated|pll1|clk[0]}
create_generated_clock -master_clock pclk_4x_source -source {scanconverter_inst|pll_linetriple|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 4 -duty_cycle 50.00 -name pclk_4x {scanconverter_inst|pll_linetriple|altpll_component|auto_generated|pll1|clk[1]}
create_generated_clock -master_clock pclk_5x_source -source {scanconverter_inst|pll_linedouble|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 5 -duty_cycle 50.00 -name pclk_5x {scanconverter_inst|pll_linedouble|altpll_component|auto_generated|pll1|clk[1]}

# retrieve post-mapping clkmux output pin
set clkmux_output [get_pins scanconverter_inst|mux5_inst|LPM_MUX_component|auto_generated|muxlut_result*|combout]

# specify postmux clocks which clock postprocess pipeline
create_generated_clock -master_clock pclk_1x -source [get_ports PCLK_in] -multiply_by 1 -name pclk_1x_postmux $clkmux_output
create_generated_clock -master_clock pclk_2x -source [get_pins scanconverter_inst|pll_linedouble|altpll_component|auto_generated|pll1|clk[0]] -multiply_by 1 -name pclk_2x_postmux $clkmux_output -add
create_generated_clock -master_clock pclk_3x -source [get_pins scanconverter_inst|pll_linetriple|altpll_component|auto_generated|pll1|clk[0]] -multiply_by 1 -name pclk_3x_postmux $clkmux_output -add
create_generated_clock -master_clock pclk_4x -source [get_pins scanconverter_inst|pll_linetriple|altpll_component|auto_generated|pll1|clk[1]] -multiply_by 1 -name pclk_4x_postmux $clkmux_output -add
create_generated_clock -master_clock pclk_5x -source [get_pins scanconverter_inst|pll_linedouble|altpll_component|auto_generated|pll1|clk[1]] -multiply_by 1 -name pclk_5x_postmux $clkmux_output -add

# specify output clocks that drive PCLK output pin
set pclk_out_port [get_ports HDMI_TX_PCLK]
create_generated_clock -master_clock pclk_1x_postmux -source $clkmux_output -multiply_by 1 -name pclk_1x_out $pclk_out_port
create_generated_clock -master_clock pclk_2x_postmux -source $clkmux_output -multiply_by 1 -name pclk_2x_out $pclk_out_port -add
create_generated_clock -master_clock pclk_3x_postmux -source $clkmux_output -multiply_by 1 -name pclk_3x_out $pclk_out_port -add
create_generated_clock -master_clock pclk_4x_postmux -source $clkmux_output -multiply_by 1 -name pclk_4x_out $pclk_out_port -add
create_generated_clock -master_clock pclk_5x_postmux -source $clkmux_output -multiply_by 1 -name pclk_5x_out $pclk_out_port -add

derive_clock_uncertainty

# input delay constraints
set TVP_dmin 0
set TVP_dmax 1.5
set critinputs [get_ports {R_in* G_in* B_in* HSYNC_in VSYNC_in FID_in}]
foreach_in_collection c [get_clocks "pclk_1x pclk_*_source"] {
    set_input_delay -clock $c -min $TVP_dmin $critinputs -add_delay
    set_input_delay -clock $c -max $TVP_dmax $critinputs -add_delay
}

# output delay constraints
set IT_Tsu 1.0
set IT_Th -0.5
set critoutputs_hdmi [get_ports {HDMI_TX_RD* HDMI_TX_GD* HDMI_TX_BD* HDMI_TX_DE HDMI_TX_HS HDMI_TX_VS}]
foreach_in_collection c [get_clocks pclk_*_out] {
    set_output_delay -clock $c -min $IT_Th $critoutputs_hdmi -add
    set_output_delay -clock $c -max $IT_Tsu $critoutputs_hdmi -add
}
set_false_path -to [remove_from_collection [all_outputs] $critoutputs_hdmi]


### CPU/scanconverter clock relations ###

# Treat CPU clock asynchronous to pixel clocks 
set_clock_groups -asynchronous -group \
                            {clk27} \
                            {pclk_1x pclk_1x_postmux pclk_1x_out} \
                            {pclk_2x_source pclk_2x pclk_2x_postmux pclk_2x_out} \
                            {pclk_3x_source pclk_3x pclk_3x_postmux pclk_3x_out} \
                            {pclk_4x_source pclk_4x pclk_4x_postmux pclk_4x_out} \
                            {pclk_5x_source pclk_5x pclk_5x_postmux pclk_5x_out}

# Ignore paths from registers which are updated only at leading edge of vsync
set_false_path -from [get_registers {scanconverter_inst|H_* scanconverter_inst|V_* scanconverter_inst|X_* scanconverter_inst|SL_* scanconverter_inst|LT_POS_* scanconverter_inst|FID_1x}]

# Ignore paths from registers which are updated only at leading edge of hsync
set_false_path -from [get_registers {scanconverter:scanconverter_inst|line_idx scanconverter:scanconverter_inst|line_out_idx* scanconverter:scanconverter_inst|hmax*}]

# Ignore paths to latency tester sync regs
set_false_path -to [get_registers {lat_tester:lt0|mode_synced* lat_tester:lt0|VSYNC_in_* lat_tester:lt0|trigger_*}]


### JTAG Signal Constraints ###

#constrain the TCK port
#create_clock -name tck -period "10MHz" [get_ports altera_reserved_tck]
#cut all paths to and from tck
set_clock_groups -exclusive -group [get_clocks altera_reserved_tck]
#constrain the TDI port
set_input_delay -clock altera_reserved_tck 20 [get_ports altera_reserved_tdi]
#constrain the TMS port
set_input_delay -clock altera_reserved_tck 20 [get_ports altera_reserved_tms]
#constrain the TDO port
#set_output_delay -clock altera_reserved_tck 20 [get_ports altera_reserved_tdo]
