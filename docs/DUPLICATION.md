# 选题复查：2026-11-07

决定：选择 MoonRRA，开发固定容量、多级聚合的循环归档核心。结论为“具备差异化空间”，不是官方查重通过证明。

使用 moon search（limit 30）重新检索 rrd、rrdtool、round robin、retention、timeseries。rrd/rrdtool 没有结果；其余检索结果包含遥测分析、查询、InfluxDB 客户端和其他保留策略项目。GitHub 仓库搜索 `rrd language:MoonBit` 无结果。限制：词汇和结果上限会遗漏项目，不能由零结果证明唯一。

前次检索还覆盖 time series、downsample、whisper、graphite、tsdb，并阅读下列公开 README；本次确认最相近的 Gorilla 仓库更新时间为 2026-09-30。

| 相关项目 | 已有能力 | 本项目边界 |
| --- | --- | --- |
| [MoonSignalKit](https://github.com/cn-wn/moonsignalkit) | 窗口统计、平滑、遥测分析 | 多精度循环归档及恢复状态 |
| [MoonPromQL](https://github.com/Santa968/moonpromql) | 内存时序查询 | 不重新实现查询语言 |
| [Gorilla](https://github.com/xie-wei10/moonbit-gorilla) | 无损压缩归档、块索引和查询适配 | 固定容量、有损聚合、过期覆盖 |
| [MoonFlux](https://github.com/zkc-long/moonflux) | InfluxDB 协议及客户端 | 无需外部数据库的可嵌入核心 |

实现差异应由 `archive.mbt` 中的有界环形归档、多倍数聚合，以及测试里的缺测/大间隔/覆盖行为证明，不能仅靠项目名称。当前是关键词和公开文档层面的生态复查，未做全生态逐行源码比对；相关领域已有库，仍有中等重叠风险。

参考成熟项目：[RRDtool](https://oss.oetiker.ch/rrdtool/doc/rrdcreate.en.html)。本项目明确采用对齐采样子集，暂未通过 RRDtool 差分验证，也不声称兼容其所有语义。
