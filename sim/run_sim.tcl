cd [file dirname [info script]]
cd ../code/code

create_project -force sim_test ../sim_test -part xc7a35tcsg324-1

add_files -fileset sim_1 -norecurse {
    alu.v
    ctrl.v
    ctrl_encode_def.v
    dm.v
    EXT.v
    im.v
    NPC.v
    PC.v
    RF.v
    SCPU.v
    sccomp.v
    sccomp_tb.v
}

set_property top sccomp_tb [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {2000ns} -objects [get_filesets sim_1]

launch_simulation
run all
close_sim
