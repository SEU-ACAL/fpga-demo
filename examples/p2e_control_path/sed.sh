#!/usr/bin/env bash

# This script should be run from the out directory
# It uses the current directory as CASE_HOME

WORK_DIR=$(pwd)

# Step 1: C_SRC - Generate C source files from templates
cp $WORK_DIR/src/c_src/template.vvac_main.cc   $WORK_DIR/src/c_src/vvac_main.cc
cp $WORK_DIR/src/c_src/template.CMakeLists.txt $WORK_DIR/src/c_src/CMakeLists.txt
cp $WORK_DIR/src/c_src/template.vmri.json      $WORK_DIR/src/c_src/vmri.json

# Create vvacDir if it doesn't exist
mkdir -p $WORK_DIR/vvacDir
cp $WORK_DIR/src/c_src/template.tbserver.toml  $WORK_DIR/vvacDir/tbserver.toml

# Replace placeholders with actual paths
sed -i "s#YOUR_CASE_HOME#$WORK_DIR/#g"           $WORK_DIR/src/c_src/vvac_main.cc
sed -i "s#YOUR_CASE_HOME#$WORK_DIR/#g"           $WORK_DIR/src/c_src/CMakeLists.txt
sed -i "s#YOUR_CASE_HOME.vcom_sim#$WORK_DIR/#g"  $WORK_DIR/src/c_src/vmri.json
sed -i "s#YOUR_CASE_HOME#$WORK_DIR/#g"           $WORK_DIR/vvacDir/tbserver.toml

sed -i "s#YOUR_FPGA_ID#0#g"                      $WORK_DIR/src/c_src/vvac_main.cc

# Prepare build directory
rm -rf   $WORK_DIR/src/c_src/build
mkdir -p $WORK_DIR/src/c_src/build
cp $WORK_DIR/src/c_src/vmri.json $WORK_DIR/src/c_src/build

echo "C source files generated successfully"

