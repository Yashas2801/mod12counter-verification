# mod12counter-verification
mod-12-loadeble-up-down-counter verification using systemverilog 
This counter gives 100% functional coverage.
All the TB components,test, module top written in one file
  How to simulate: 1) From Questa GUI :Use Questasim, Create a project , copy the .sv file and .do file instde the project, in questa terminal, use command do run.do 
                   2) Using linux commands : vlib work 
                                             vlog -sv mod12counter.sv
                                             vsim -coverage top +TEST1 -do "run -all; exit"
