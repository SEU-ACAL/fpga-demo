#!/bin/bash
# ============================================================================
# Environment Setup Script
# ============================================================================
# This script sets up all required environment variables for FPGA P2E flow
# Usage: source ./sourceme.sh

# Set HPEC home directory
export HPEC_HOME=/home/x-epic/hpe-24.12.01.s008

# Source HPE setup script (sets VCOM_HOME, VDBG_HOME, VSYN_HOME, etc.)
source $HPEC_HOME/.setup.sh

# Vivado tool paths
export VIVADO_PATH=/home/tools/vivado/Vivado/2022.2
export PATH=$VIVADO_PATH/bin:$PATH
export PATH=$VIVADO_PATH/gnu/microblaze/lin/bin:$PATH

# Additional tool paths
export PATH=$HPE_HOME/tools/xwave/bin:$PATH

# License configuration
export RLM_LICENSE=5053@192.168.99.15
export LM_LICENSE_FILE=/home/tools/vivado/license.lic
