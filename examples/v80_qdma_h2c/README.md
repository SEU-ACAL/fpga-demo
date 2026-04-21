# V80 QDMA DMA H2C/C2H Write/Read Test

Host 侧 DMA 数据通路验证：通过 QDMA MM 模式执行 H2C 写入 + C2H 读回，比对数据一致性。

V80 使用 CPM5 硬核 QDMA，FPGA 设计基于 AVED 基线工程。本例只做 host 侧测试。

## Prerequisites

- QDMA 驱动已安装并加载（参考 `drivers/qdma/install_qdma.sh`）
- V80 AVED 设计已部署（通过 `ami_tool` 或 JTAG 烧写 PDI）
- `dma-ctl` 工具可用（随 QDMA 驱动编译产生）

## Run

```bash
./run.sh
```

自动完成：发现 QDMA 设备 → 配置队列（qmax / add / start）→ DMA 写入+读回测试 → 清理队列。

多卡环境下指定目标卡：

```bash
BUS_ID=0000:21:00.1 ./run.sh
```

可调参数（环境变量）：

```bash
DMA_SIZE=65536 DMA_OFFSET=0x1000 ./run.sh      # 自定义传输大小和偏移
QMAX=4 QUEUE_H2C=0 QUEUE_C2H=1 ./run.sh        # 自定义队列配置
```

也可以直接运行测试脚本（需先手动配置队列）：

```bash
python3 ./test_h2c.py --h2c /dev/qdma21001-MM-0 --c2h /dev/qdma21001-MM-1 --size 4096
```

## Troubleshooting

- **no QDMA PCIe device found**: 检查 QDMA 驱动是否加载，`lspci -d 10ee:50b5` 有无输出
- **qmax not found**: QDMA 驱动未绑定到目标设备，检查 `install_qdma.sh` 步骤
- **device not found after queue start**: `dma-ctl` 队列添加/启动失败，检查 `dma-ctl qdmaXXXXX q list`
- **data compare failed**: 检查 FPGA 侧 BRAM 或 DDR 地址映射、DMA 地址范围
- **short write/read**: 传输大小超过 FPGA 侧可用存储空间
