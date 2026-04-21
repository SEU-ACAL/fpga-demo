# V80 QDMA User BAR (AXI-Lite MMIO) Test

最小 host 例子：通过 QDMA user 节点做 BAR/MMIO 读写验证。

这个例子只做用户态交互，不负责加载驱动或刷卡。

## Prerequisites

- 系统已安装并加载 QDMA 驱动
- 存在 user 设备节点，例如 `/dev/qdma00000-user`

## Build

```bash
vivado -mode batch -source build.tcl -tclargs ./build xcu280-fsvh2892-2L-e
```

说明：
- 这个目录重点是 host 侧 `qdma*-user` 用法
- `create_bd.tcl` 是占位脚本，不生成可用 QDMA 独立设计
- 真正 QDMA 硬件集成请从 AVED 基线工程做

## Run

```bash
./run.sh
```

多卡或多函数场景可显式指定设备：

```bash
QDMA_USER_DEV=/dev/qdma00000-user ./run.sh
```

也可以直接运行测试脚本：

```bash
python3 ./test_user.py --dev /dev/qdma00000-user --offset 0x0 --count 64
```

## Troubleshooting

- **No qdma user device found**: 检查 QDMA 驱动是否加载，确认 `/dev/qdma*-user` 存在
- **compare mismatch**: 检查 FPGA 侧 BAR 地址映射和寄存器可读回属性
