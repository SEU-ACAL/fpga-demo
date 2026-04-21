# AU280 XDMA H2C Write/Read Test

最小 Vivado 工程：XDMA → BRAM，验证 PCIe H2C/C2H DMA 通路。

## Build

```bash
vivado -mode batch -source build.tcl -tclargs ./build xcu280-fsvh2892-2L-e
```

## Run

```bash
./run.sh
```

自动完成：flash bitstream → PCIe remove/rescan → xdma 驱动重载 → H2C write/read 测试。

多卡环境下指定目标卡：
```bash
BUS_ID=0000:e2:00.0 ./run.sh
```

## Troubleshooting

- **H2C 写返回 -512**: 烧完 bitstream 没做 PCIe remove/rescan
- **insmod: File exists**: udev 自动加载了 xdma，先 `sudo rmmod xdma` 再 insmod
- **BDF 检测错误**: 多卡时用 `BUS_ID=0000:xx:00.0 ./run.sh` 指定
