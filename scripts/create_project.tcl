# Recreate the Vivado project from source.
#
#   vivado -mode batch -source scripts/create_project.tcl
#
# Builds ./build/arcade.xpr from rtl/, sim/ and constraints/. The build
# directory is gitignored, so this script is the only thing that needs to
# stay in sync with the sources.

set part      "xc7a100tcsg324-1"
set top       "arcade_top"
set sim_top   "tb_arcade_top"
set proj      "arcade"
set root      [file normalize [file dirname [info script]]/..]
set build_dir "$root/build"

file mkdir $build_dir
create_project -force $proj $build_dir -part $part

add_files -fileset sources_1 [glob $root/rtl/*.v]
add_files -fileset sim_1     [glob $root/sim/*.v]
add_files -fileset constrs_1 [glob $root/constraints/*.xdc]

set_property top $top     [get_filesets sources_1]
set_property top $sim_top [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project created at $build_dir/$proj.xpr"
puts "Synthesize: launch_runs synth_1 -jobs 4"
puts "Bitstream : launch_runs impl_1 -to_step write_bitstream -jobs 4"
