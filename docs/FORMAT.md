# 二进制快照 v1

所有字段为小端 8 字节。Double 使用 IEEE 754 binary64 位模式。头部：magic=0x4152524D，version=1，step，latest，归档数。

每个归档依次编码 factor、rows、aggregation（0 平均/1 最小/2 最大/3 最后已知值）、min_known、pending_bucket、pending_count、mean、low、high、last、已保留记录数。记录按时间顺序编码，每条为 timestamp、存在标记（0/1）、Double 值（缺失时为0）。末尾为前面所有字节的32位 FNV-1a，零扩展存入8字节。

pending_bucket 是从 Unix 原点开始计数的当前未完成桶号；快照保留累积状态，因此恢复后可继续当前桶。恢复时检查版本、长度、校验、配置上限、时间对齐、桶顺序、计数、有限浮点数及尾部多余数据。该格式不兼容 RRDtool .rrd。
