# Usage (Vivado Tcl console or batch):
#   vivado -mode batch -source scripts/create_project.tcl          (create project)
#   vivado -mode gui   -source scripts/create_project.tcl          (create + open)
# Target: RealDigital Boolean Board (Spartan-7 XC7S50)
set part   xc7s50csga324-1
set root   [file normalize [file join [file dirname [info script]] ..]]
set proj   pl_riscv_cpu

create_project -force $proj [file join $root vivado_proj] -part $part

# --- design sources ---
add_files -fileset sources_1 [concat \
    [glob [file join $root rtl *.v]] \
    [glob [file join $root rtl components *.v]]]
foreach m {rv32i_test.mem rv32i_sys_test.mem} {
    add_files -fileset sources_1 [file join $root sim $m]
    set_property file_type {Memory Initialization Files} [get_files $m]
}
add_files -fileset sources_1 [file join $root rtl board boolean_top.v]
add_files -fileset constrs_1 [file join $root constraints boolean_board.xdc]
set_property top boolean_top [get_filesets sources_1]

# --- simulation sources ---
add_files -fileset sim_1 [list [file join $root sim tb.v] [file join $root sim tb_system.v] \
                              [file join $root sim tb_boolean.v]]
foreach m {rv32i_test.mem rv32i_sys_test.mem} {
    add_files -fileset sim_1 [file join $root sim $m]
    set_property file_type {Memory Initialization Files} \
        [get_files -of_objects [get_filesets sim_1] $m]
}
set_property top tb [get_filesets sim_1]
set_property xsim.simulate.runtime {all} [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Sources: [llength [get_files -of_objects [get_filesets sources_1]]] files in sources_1"
puts "Project created. Run: launch_simulation   (or Flow Navigator > Run Simulation)"
