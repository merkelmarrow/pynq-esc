# Thottle input on JA1P (Y18), top-right input on Pmod A
set_property PACKAGE_PIN Y18 [get_ports {rc_pwm_in}]
    set_property IOSTANDARD LVCMOS33 [get_ports {rc_pwm_in}]
    set_property PULLDOWN YES [get_ports {rc_pwm_in}]
    set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of [get_ports {rc_pwm_in}]]
    set_false_path -from [get_ports {rc_pwm_in}]