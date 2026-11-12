# RRDtool 对照范围

执行 `python3 tools/compare-rrd.py`，需要 Native C 编译环境、MoonBit 和 RRDtool CLI。脚本创建临时 .rrd，向 RRDtool 与 MoonRRA 输入相同的12次严格对齐 GAUGE 更新，比较4种聚合的16个时间桶，包括可容忍的单点缺失和导致未知桶的双点缺失；浮点相对/绝对容差为1e-12。临时文件由脚本清理。

参考 [RRDtool rrdcreate](https://oss.oetiker.ch/rrdtool/doc/rrdcreate.en.html) 的 GAUGE、RRA、xff 定义。样例为本项目自行构造，调用外部 RRDtool 二进制，不分发其源码。当前结果不能推及非对齐输入、heartbeat、COUNTER 回绕或 .rrd 文件兼容。
