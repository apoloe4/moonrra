# MoonRRA

纯 MoonBit 固定容量、多分辨率时序归档库。适用于服务监控、设备采样与网络流量历史：近期保留细节，长期保留聚合值，以固定数量的记录限制空间占用。

当前版本 **0.1.0**。核心、快照编解码和计数器转换全部使用 MoonBit，无 C/JS 库封装，无第三方运行时依赖。算法参考 RRD 思路，采用独立、明确的对齐采样语义。

## 安装与运行

需要 `moonc >= 0.10.20`（满足赛事要求的 0.10.16 下限）。Native 目标另外需要 C 编译器。

```sh
git clone https://github.com/apoloe4/moonrra.git
cd moonrra
moon update
moon check --deny-warn
moon build --deny-warn
moon test --deny-warn
moon run examples/basic
moon run examples/sensor
moon run examples/traffic
```

已发布 [Mooncakes 0.1.0](https://mooncakes.io/docs/apoloe4/moonrra@0.1.0)，可运行 `moon add apoloe4/moonrra@0.1.0`。独立消费者验证：`node tools/verify-consumer.mjs <新的空目录路径>`。

在调用方 `moon.pkg` 中添加：

```text
import { "apoloe4/moonrra" @rra }
```

下列代码放在可以抛出错误的函数或测试体内：

```moonbit nocheck
let db = @rra.Store::new(60, [
  @rra.Spec::new(1, 1440, Last),
  @rra.Spec::new(60, 720, Average, min_known=30),
])
db.update(60L, Some(20.0))
db.update(120L, Some(22.0))
let points = db.fetch(0, 0L, 120L)
let bytes = db.snapshot()
let restored = @rra.Store::restore(bytes)
```

## 已实现

- 1 秒至 1 天基础步长；每个归档独立设置聚合倍数、容量与最少已知点数。
- 平均、最小、最大与最后一个已知值四种聚合。
- 固定容量环形存储，自动填补缺测；跨越巨大时间间隔时只处理有限的保留区间。
- 指定归档的区间查询、实际覆盖区间与未完成桶状态查询。
- 版本化二进制快照，完整性校验、资源限制、非法输入拒绝；保存未完成聚合状态。
- 显式 32 位计数器速率转换，重置返回缺失值，回绕必须主动开启。
- 三个可运行样例；包含批处理参考模型对照、循环覆盖、缺测、快照续写、损坏与截断输入的测试。

## 时间与缺失值语义

时间戳是**正整数 UTC 秒**，以 `Int64` 表示，必须严格递增、对齐基础步长，上限为 9×10^15。一个输入值代表结束于该时间戳的基础区间。非对齐输入直接报错，不插值。

每个聚合桶覆盖 `(桶结束时间 - 分辨率, 桶结束时间]`。只有已经结束的桶才可查询；`info` 提供 `pending_known`。第一次输入之前的完整桶不创建，起始桶未提供的点视为未知。

`None` 和跳过的采样时刻都表示未知，零是有效值。`min_known` 是桶内最少已知采样数量；达标后平均值只除以已知点数。`Last` 是最后一个已知值，桶末尾缺失不会将之前已知值改为零。丢失时间间隔不会延长上个值的有效期。

`fetch(index, start, end)` 返回 `(start, end]` 内仍保留的完整桶。已过期/未建立的历史不返回；保留范围内的未知桶返回 `None`，使用 `info` 区分。每个 Store 表示一条指标序列，多指标由调用方分别创建。

## 容量、持久化与限制

所有归档最多 100 万记录、最多 32 个归档，每个倍数最多 100 万。固定配置下核心历史状态有界；快照/查询会额外分配输出内存，快照按已存在记录编码，因此大小可增长至上限后稳定。

`snapshot` / `restore` 负责字节序列；文件、对象存储或浏览器存储由调用方接入。当前不提供原地文件写入、事务或断电恢复保证。FNV-1a 只检查意外损坏，不是密码学认证。

首版不兼容 `.rrd` 文件格式，不实现 RRDtool 不规则采样插值、heartbeat、完整 COUNTER/DERIVE 数据源，也不提供 PromQL、标签索引或网络服务。32 位计数器的重置与回绕无法自动可靠区分，须由调用方明确选择。浮点结果允许舍入误差。

## 研发与验收

```sh
moon fmt --check
moon check --deny-warn --target all
moon build --deny-warn --target all
moon test --deny-warn --target all
moon info
```

GitHub Actions 在 wasm-gc、wasm、js、native 四个目标执行检查、构建、测试和样例，另有格式与接口检查。

- [查重与生态定位](docs/DUPLICATION.md)
- [功能范围与后续计划](docs/SCOPE.md)
- [快照格式](docs/FORMAT.md)

Apache-2.0，详见 [LICENSE](LICENSE)。独立实现；参考 [RRDtool 文档](https://oss.oetiker.ch/rrdtool/doc/rrdcreate.en.html) 中的循环归档概念，未移植 RRDtool 源码。




## 0.1.0 发布验证

[完整验证记录](docs/VALIDATION.md)；[项目申报书](docs/PROPOSAL.md)。

