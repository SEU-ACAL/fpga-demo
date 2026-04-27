#!/bin/bash
# ============================================================================
# Environment Setup Script for P2E Control Path
# ============================================================================
# This script sets up all required environment variables for FPGA P2E flow
# Usage: source ./sourceme.sh

# Set HPEC home directory
export HPEC_HOME=/build/daily/centos-x86/hpe/xepic/26.06.00/latest

# Source HPE setup script (sets VCOM_HOME, VDBG_HOME, VSYN_HOME, etc.)
if [ -f "$HPEC_HOME/.setup.sh" ]; then
    source "$HPEC_HOME/.setup.sh"
fi

# Project-specific environment variables
unset P2E_V2_TEST
unset VCOM_TEST_DIP
unset GALAXSIM_HOME

export CASE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TBSERVER_ETC="$CASE_HOME/vvacDir/runtimeDir/"
export VVAC_GEN="$CASE_HOME/vvacDir/vvac_by_mod/"
export top_module="xepic_vvac_top"
export VVAC_WORK_DIR="$CASE_HOME/vvacDir/"
export NEWBACKDOOR=1
export CC="$HPEC_HOME/tools/gcc-8.3.0/gcc-8.3.0/bin/gcc"
