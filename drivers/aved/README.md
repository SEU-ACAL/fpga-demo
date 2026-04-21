# V80 AVED 驱动与 PDI 构建


```bash
git clone -b amd_v80_gen5x8_24.1_20241002 https://github.com/Xilinx/AVED.git
./clone_aved.sh         # 拉源码到 AVED/
./build_ami.sh          # 本机编 ami.ko + ami_tool
./build_pdi.sh          # 需要 Vivado 2024.1
./install_aved.sh       # 装 AMI、烧 PDI
```

烧完 PDI 重启或 PCIe rescan 后，应能看到 `lspci -d 10ee:50b5` 有输出，再回到 `examples/v80_qdma_*/run.sh`。
