# AU280 XDMA User BAR (AXI-Lite MMIO) Test

最小 Vivado 工程：XDMA M_AXI_LITE → BRAM，验证 User BAR MMIO 读写通路。
通过 `/dev/xdmaN_user` 做 mmap 读写，不走 DMA 引擎。

## Build

```bash
vivado -mode batch -source build.tcl -tclargs ./build xcu280-fsvh2892-2L-e
```

## Run

```bash
./run.sh
```

多卡环境：
```bash
BUS_ID=0000:e2:00.0 ./run.sh
```

## Troubleshooting

- **mmap 失败**: 检查 `/dev/xdmaN_user` 权限，`sudo chmod a+rw /dev/xdma*`
- **读回全 0 或全 F**: BRAM 地址映射问题，检查 `create_bd.tcl` 中的 `assign_bd_address`
