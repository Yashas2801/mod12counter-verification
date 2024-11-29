
# Mod-12-Counter

A project to verify the loadable mod 12 up down counter using system verilog and get 100% coverage




## Run Locally Using Questasim GUI terminal

Create a working liberary

```bash
  vlib work
```

Compile your SystemVerilog code

```bash
  vlog -sv mod_12_counter.sv
```

Simulate your design with coverage enabled

```bash
  vsim -coverage top +TEST1 -do "run -all; exit"
```


