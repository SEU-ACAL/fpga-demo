#!/bin/csh -f

source ./setup.env.csh

# Synthesis
make vvac
make vsyn

# System build
make vcom

# C build
source make_sed.csh
source make_c_tester.csh

# PNR
cd fpgaCompDir
make all
cd ..

# Run on board
source run_vdbg.csh
