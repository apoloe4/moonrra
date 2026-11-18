# 从采集到设备组查询

## 先用固定输入验证

在仓库根目录运行 `moon update`。Node 22.13+ 不需要 C 编译器：

```sh
moon run examples/collector_node --target js -- fixtures/telegraf.ndjson
moon run examples/fleet --target js
```

第一条读取 6 行，两台主机各有一条温度序列。east 在 10、20、30、40、50 秒的桶依次为 14、19、null、null、23；west 在 10 秒为 0。结束行是 `series_count=2, too_late=1, series_limit=0, ignored=0`（JSON）。若有 Native 工具链，可用 `moon run examples/collector --target native -- fixtures/telegraf.ndjson`。两种文件入口调用同一 MoonBit 解码器和回放函数。

第二条按 east、west、north 三个预期设备查询；两个设备有读数时均值为 21，一台停报后不再输出均值：

```
end=10 reporting=2 missing=0 unavailable=1 mean=21
end=20 reporting=1 missing=1 unavailable=1 mean=unknown
```

## 接入 Telegraf

仓库提供 `fixtures/telegraf.conf`，只收集 `mem.available` 与 `mem.used_percent`，以 Unix 秒、每行一个 JSON 对象输出。安装 Telegraf 后，在 POSIX shell 中执行：

```sh
telegraf --config fixtures/telegraf.conf --once > mem.ndjson
moon run examples/collector_node --target js -- mem.ndjson > rows.ndjson
node tools/check-collector.mjs live rows.ndjson mem.ndjson
```

最后一条逐字段核对刚采到的数值、主机标签和桶结束时间，不依赖预设的内存值。CI 使用同样的配置在 Linux 中运行 Telegraf 1.36.0，并走 Native 入口。文件回放只处理一份已经写完的 UTF-8 文件（最多 4 MiB）；反复启动命令不会合并多批数据。

## 嵌入持续运行的采集程序

应用启动时创建一次 `Collector`，保留到进程退出。收到一条 Telegraf 记录时调用 `telegraf.decode`，遍历结果调用 `observe(key,time,value)`，按返回值记录拒收/覆盖。可直接喂入自有协议解出的序列键、UTC 秒和数值，不依赖 Telegraf。由调用方选择可信的截止时间调用 `advance(key, through)`；它会关闭已完整经过的桶，静默期间记为缺测。正常流中不要逐包 `flush()`；仅在确定输入结束时结清最后一桶。

| 情况 | 结果 |
| --- | --- |
| 在未关闭的桶内 | 该桶保留事件时间最大的一条；相同时间保留先到值；较旧值返回 `Superseded` |
| 一条序列的最大事件时间为 T | 关闭结束时间 ≤ T − lateness 的完整桶；时钟独立，不由别的设备推进 |
| 样本所属桶已经关闭 | 返回 `TooLate`，不改历史 |
| 新序列超出上限 | 返回 `SeriesLimit`，已有序列仍可写入 |
| 输入不是秒级单指标对象，标签非字符串，或无数值字段 | 回放报行号并退出；同一记录中的其他非数值字段忽略 |

文件示例固定 10 秒步长、20 秒迟到窗口、每条保留最近 30 桶、最多 128 条序列。库可配置；每序列最多约 `ceil(lateness / step) + 1` 个待结算桶，不保留原始事件列表。输入应为仪表值（gauge）；累计值需先转换为速率。

`cohort(keys, archive, start, end, min_reporting=...)` 在 `(start,end]` 按归档分辨率对齐，调用方指定**同单位、同含义**的成员名单。`reporting` 包括真实零；`missing` 是仍然保留但没有有效值的桶；`unavailable` 包括尚未建立、尚未结算或已覆盖的历史。三者之和等于名单大小；均值只使用报告成员，未达门槛返回 `None`。限制每次 4096 桶、100 万个成员×桶，拒绝重复名单。未提供标签搜索、跨进程连续采集或检查点恢复；单条 `Store` 的快照不包含采集窗口。

格式依据：[Telegraf JSON 序列化](https://github.com/influxdata/telegraf/blob/v1.36.0/plugins/serializers/json/README.md)、[file 输出配置](https://github.com/influxdata/telegraf/blob/v1.36.0/plugins/outputs/file/sample.conf)。
