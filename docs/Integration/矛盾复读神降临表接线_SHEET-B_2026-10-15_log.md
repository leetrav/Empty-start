# SHEET-B 2026-10-15 紧急内测局部数值修复

对照已批准 10、15 策划 CSV，修正原生 Resource 中已确认的两处旧值：
- 10 表 contradiction_repeat_lifetime_s = 10，data/sandbox/playable_battle_config.tres 中正式 contradiction_repeat_lifetime_seconds 从 6 秒改为 10 秒。
- 15 表 new_word_decay_s = 12，data/divine_descent/divine_descent_decay_config.tres 中正式 new_word_decay_duration_seconds 从 60 秒改为 12 秒。

这两处均直接由既有消费者使用，无新增控制器。11、12、15 表其余字段未完成一对一映射，本次不能宣称全表生效。合并后必须跑最新 main 的生产数据门禁、Windows 构建与运行，并在人工试玩中确认时间轴。
