# P2E FPGA 板上使用 DPI-C 的完整流程

本指南说明如何在 P2E FPGA 板上使用 DPI-C 进行 RTL 和 C 代码的交互测试。

## 前置条件

- 已安装 XEPIC HPE 工具链（VVAC、VCOM、VSYN、VDBG）
- 已配置 FPGA 板连接
- 已安装 cmake 和 gcc

## 目录结构

```
p2e_control_path/
├── src/
│   ├── dut_rtl/dut_src/          # RTL 设计文件
│   │   ├── dut.sv                # DUT 模块（包含 DPI-C import/export）
│   │   └── dut_top.sv            # 顶层模块
│   └── c_src/                    # C 测试代码
│       ├── template.vvac_main.cc # C 主程序模板
│       └── template.CMakeLists.txt # CMake 配置模板
├── build.sh                      # 完整构建脚本
├── run.sh                        # 运行测试脚本
├── debug.tcl                     # VDBG 调试脚本
├── run_c_test.sh                 # C 程序启动脚本
├── sed.sh                        # 路径替换脚本
└── sourceme.sh                   # 环境变量配置
```

## 使用流程

### 第一步：编写 RTL 代码（DUT）

在 `src/dut_rtl/dut_src/dut.sv` 中定义 DPI-C 接口：

#### 1.1 Import 函数（C 调用 RTL）

```systemverilog
// 在 RTL 中声明要调用的 C 函数
import "DPI-C" context function void func_touch(output bit [7:0] s2h_data_out0);
```

#### 1.2 Export 函数（RTL 调用 C）

```systemverilog
// 导出 RTL 函数供 C 代码调用
export "DPI-C" function func_get_rtl_value;

function void func_get_rtl_value(output bit [WIDTH1-1:0] o1, output bit [WIDTH1-1:0] o2);
    o1 = s2h_out1;
    o2 = q_out;
endfunction
```

#### 1.3 在 RTL 中调用 C 函数

```systemverilog
always @(posedge clk) begin
    if (rstn == 1) begin
        if (&q_out[2:0]) begin
            func_touch(s2h_data_out0);  // 调用 C 函数
            func1_toggle <= ~func1_toggle;
        end    
    end 
end
```

#### 1.4 通知机制（可选）

```systemverilog
// 在 dut_top.sv 中定义通知函数
import "DPI-C" context function void dut_notice(input bit [31:0] h2s_data);

always @(posedge clk) begin 
    if (ris_flag_done) begin 
        dut_notice(cycle_cnt);  // 通知 C 程序测试完成
    end 
end
```

### 第二步：编写 C 测试代码

在 `src/c_src/template.vvac_main.cc` 中实现 DPI-C 函数：

#### 2.1 实现 Import 函数（被 RTL 调用）

```cpp
// 实现 RTL 中 import 的函数
extern "C" void func_touch(uint32_t *o0)
{
    std::cout << "func_touch called" << std::endl;
    *o0 = 25;  // 返回数据给 RTL
    std::cout << "expect 25, PASS" << std::endl;
}

extern "C" void dut_notice(uint32_t *iVec1)
{
    printf("dut_notice: cycle count = %x\n", *(iVec1 + 0));    
    dut_notice_value = *(iVec1 + 0);  // 设置完成标志
}
```

#### 2.2 调用 Export 函数（调用 RTL）

```cpp
// 声明 RTL 中 export 的函数
extern "C" void func_get_rtl_value(uint32_t* h2sdat_1, uint32_t* h2sdata_2);

// 在 C 代码中调用
void test_dpic()
{
    vvac::ICtbMgr *ctb_ = vvac::CtbBuilder::create();
    auto ret = ctb_->init("P0", "YOUR_CASE_HOME",
                          "YOUR_CASE_HOME/vvacDir/runtimeDir/rtcfg");
    if (ret) {
        uint32_t rtl_point, rtl_cnt;
        
        std::cout << "===TEST START===" << std::endl;
        
        // 等待 RTL 完成测试
        while(dut_notice_value == 0) { 
            sleep(1);
        }
        
        std::cout << "===TEST FINISHED===" << std::endl;
        ctb_->quit();
    } else {
        std::cout << "CTB init failed!" << std::endl;
    }
}
```

#### 2.3 主函数配置

```cpp
int main()
{
    // 设置环境变量（FPGA 板上测试模式）
    setenv("VMRI_LOG_LEVEL", "0", 1);
    setenv("VVAC_LOG_LEVEL", "0", 1);
    setenv("RBMGR_LOG_LEVEL", "0", 1);
    setenv("RBMGR_DUMP_DATA", "1", 1);
    setenv("VMRI_WORK_MODE", "3", 1);  // 3 = FPGA 板上测试
    setenv("VVAC_WORK_MODE", "0", 1);  // 0 = FPGA 板上测试
    setenv("RTL_DBG_SIZE", "128", 1);
    
    std::cout << "========= Run For Onboard Test ==========" << std::endl;
    test_dpic();
    return 0;
}
```

### 第三步：配置 CMakeLists.txt

在 `src/c_src/template.CMakeLists.txt` 中配置库路径：

```cmake
cmake_minimum_required(VERSION 3.5)
project(tester)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -lstdc++fs -fPIC -pthread -rdynamic -fvisibility=hidden")
set(CMAKE_BUILD_TYPE "Debug")

# 设置 vCtb 库路径（VVAC 生成的运行时库）
set(VCTBLIB_PATH YOUR_CASE_HOME/vvacDir/runtimeDir/lib/lib_arm/)

# 定义为 FPGA 板上测试
add_definitions(-D_ARM_)
find_library(
  VCTB_LIB
  NAMES libvCtb.so
  PATHS ${VCTBLIB_PATH}/)

# 设置头文件路径
set(INC YOUR_CASE_HOME/vvacDir/runtimeDir/include/)
link_directories(YOUR_CASE_HOME/vvacDir/runtimeDir/lib/lib_arm/)
include_directories(${INC})

# 源文件
set(SOURCES vvac_main.cc)

# 生成可执行文件
add_executable(tester ${SOURCES})
target_link_libraries(tester ${VCTB_LIB})
```

### 第四步：配置环境变量

在 `sourceme.sh` 中配置工具链路径：

```bash
#!/bin/bash

# HPEC 工具链路径
export HPEC_HOME=/home/x-epic/hpe-24.12.01.s008

# 工具路径
export PATH="$HPEC_HOME"/bin:"$PATH"
export PATH="$HPEC_HOME/tools/gcc-8.3.0/cmake-3.26.5/bin:$PATH"  # cmake 路径
export VCOM_HOME="$HPEC_HOME"
export VDBG_HOME="$HPEC_HOME"
export VSYN_HOME="$HPEC_HOME"
export VVAC_HOME="$HPEC_HOME"

# Vivado 路径
export VIVADO_PATH=/home/tools/vivado/Vivado/2022.2
export PATH=$VIVADO_PATH/bin:$PATH

# License 配置
export RLM_LICENSE=5053@192.168.99.15
export LM_LICENSE_FILE=/home/tools/vivado/license.lic

# 项目环境变量
export CASE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TBSERVER_ETC="$CASE_HOME/vvacDir/runtimeDir/"
export VVAC_GEN="$CASE_HOME/vvacDir/vvac_by_mod/"
export top_module="xepic_vvac_top"
export VVAC_WORK_DIR="$CASE_HOME/vvacDir/"
export NEWBACKDOOR=1
```

### 第五步：配置 VDBG 调试脚本

在 `debug.tcl` 中配置测试流程：

```tcl
# 设置脚本目录和信号
set script_dir [file dirname [file normalize [info script]]]
set rst_sig "dut_top.arstn"

# 加载设计并下载到 FPGA 板
design .
hw_server .
download

# 在后台启动 C 测试程序
puts "========== Starting C Tester =========="
set pid_c [exec bash $script_dir/run_c_test.sh &]
puts "C tester PID: $pid_c"

# 控制复位信号
puts "========== Reset Control =========="
force $rst_sig 0
puts "Reset asserted: [get_value $rst_sig]"
run 10rclk

force $rst_sig 1
puts "Reset deasserted: [get_value $rst_sig]"

# 运行测试（给 C 程序足够的时间完成）
puts "========== Running Test =========="
run 20000rclk

puts "========== Test Complete =========="
exit
```

### 第六步：创建 C 程序启动脚本

在 `run_c_test.sh` 中配置 C 程序启动：

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/out}"

cd "$OUT_DIR/src/c_src/build"
./tester >& "$OUT_DIR/run.tester.log" &
echo $! > "$OUT_DIR/pid.tester"
cd "$OUT_DIR"
```

### 第七步：构建和运行

#### 7.1 完整构建

```bash
cd /path/to/p2e_control_path
./build.sh
```

构建流程包括：
1. **VVAC**: 生成 VVAC 包装代码和 vCtb 运行时库
2. **VSYN**: 综合 RTL 设计
3. **VCOM**: 编译设计并插入调试 IP
4. **sed.sh**: 生成 C 源文件（路径替换）
5. **cmake + make**: 编译 C 测试程序
6. **PNR**: 布局布线生成比特流（可选，如果已有比特流可跳过）

#### 7.2 运行测试

```bash
./run.sh
```

运行流程：
1. VDBG 加载比特流到 FPGA 板
2. 在后台启动 C 测试程序
3. 控制复位信号
4. 运行指定时钟周期
5. C 程序通过 DPI-C 与 RTL 交互
6. 测试完成后退出

#### 7.3 查看结果

```bash
# 查看 C 程序输出
cat out/run.tester.log

# 查看 VDBG 输出
cat nohup.out
```
