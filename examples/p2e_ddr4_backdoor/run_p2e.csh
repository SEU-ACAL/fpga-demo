#!/bin/

# Synthesis
vsyn -f flist.lst -t pcie3_ddr4 -o rev_1/pcie3_ddr4.vm

# System build
source run_vcom.csh

# PNR
cd fpgaCompDir
make all
cd ..

# Run on board
vdbg debug.tcl
