## REQ-program-identify
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#1.身份系统
- description: 1.身份系统
- acceptance:
  ~~~~text
  DATA_880STG3C_START
  - **名称输入**：保存玩家确认的主播名，空白输入采用默认名称
  - **身份选择**：读取策划提供的人设名称、图标与对应倾向
  - **周目保存**：保存本周目的姓名和身份，身份确认后本周目内固定，重开当前关沿用已选身份
  - **平台输入**：支持PC输入，触摸适配按移动端安排接入
  DATA_880STG3C_END
  ~~~~
- scope: 1.身份系统

## REQ-program-level-configuration
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#2.关卡配置系统
- description: 2.关卡配置系统
- acceptance:
  ~~~~text
  DATA_5I6POT6O_START
  - **生成配置**：向【弹幕生成系统】提供基础数量、频率、速度和同屏上限
  - **继承内容**：从【吞并系统】读取已获得的词库与特性并用于后续关卡
  - **关卡完成**：关联【休息时刻系统】推进关卡，同一场结果只提交一次
  - **最终入口**：全部普通关卡推进完成后进入【神降临系统】
  DATA_5I6POT6O_END
  ~~~~
- scope: 2.关卡配置系统

## REQ-program-barrage-generation
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#3.弹幕生成系统
- description: 3.弹幕生成系统
- acceptance:
  ~~~~text
  DATA_JWE7OFT9_START
  - **寿命边界**：已有弹幕的到期时间保持不变，档位变化只影响后续生成的寿命
  - **同屏上限**：普通话语与陷阱共用一组上限，复读另设上限，达到对应上限时暂停生成，空出位置后继续
  - **命中移除**：收到有效命中或反弹结果后移除对应弹幕，只有遮挡未命中的目标继续保留
  - **暂停处理**：全局暂停时停止生成和寿命计时，恢复后继续
  - **阶段清理**：普通战斗转入矛盾阶段时清理普通弹幕与尚未出现的普通复读
  DATA_JWE7OFT9_END
  ~~~~
- scope: 3.弹幕生成系统

## REQ-program-barrage-traits
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#4.弹幕特性模块系统
- description: 4.弹幕特性模块系统
- acceptance:
  ~~~~text
  DATA_E90FABOB_START
  - **复制类型**：带惩罚的水军复制品使用反击弹幕规则并显示反击标记，复制品自身不继续触发复制
  - **分裂结果**：母体移除后生成两条子话语，各自使用配置的倾向、强度和独立原句标识，并保留母体截止时间
  - **特性顺序**：可选目标按反弹、遮挡、基础类型的顺序确定本次结果
  - **兼容边界**：不可选与分裂及反弹互斥，分裂与陷阱及复读互斥
  - **矛盾边界**：真假矛盾按【矛盾击破系统】规则处理，并排除普通战斗的陷阱特性
  DATA_E90FABOB_END
  ~~~~
- scope: 4.弹幕特性模块系统

## REQ-program-combat-attack
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#5.战斗攻击系统
- description: 5.战斗攻击系统
- acceptance:
  ~~~~text
  DATA_OKEFL9GT_START
  - **输入操作**：支持鼠标移动、按住和松开，触摸操作按移动端适配安排接入
  - **取消蓄力**：未蓄满松开时清空本次蓄力，不扣PK且不消耗矛盾阶段的发射机会
  - **目标记录**：释放时记录范围内的有效目标，同一发内按实例去重
  - **目标复核**：到达时复核已记录目标是否仍有效，已记录目标移动后仍可命中，后来进入范围的目标留给下一发
  - **矛盾攻击**：向【矛盾击破系统】即时报告命中集合并消耗本次发射机会
  - **暂停处理**：全局暂停时停止蓄力、飞行和硬直计时
  DATA_OKEFL9GT_END
  ~~~~
- scope: 5.战斗攻击系统

## REQ-program-hit-resolution
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#6.命中结算系统
- description: 6.命中结算系统
- acceptance:
  ~~~~text
  DATA_TOOGC9JU_START
  - **话语收益**：按每条正常话语的强度读取固定PK与倾向增量，狂热档位不额外提高命中奖励，数值引用【各数值表】
  - **同发汇总**：将本发所有目标的收益与扣分相加后统一更新PK
  - **异常合并**：每发按反弹、遮挡、落空的顺序至多选择一种异常
  - **反弹边界**：同一个反弹目标只应用反弹异常扣分，引用【各数值表】
  - **复读命中**：复读按零收益事件结算并算作有效命中，引用【各数值表】
  - **回拉优先**：回拉在本次命中时刻已使PK归零时，取消该次命中
  DATA_TOOGC9JU_END
  ~~~~
- scope: 6.命中结算系统

## REQ-program-opponent-pk-bar
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#7.对手PK条系统
- description: 7.对手PK条系统
- acceptance:
  ~~~~text
  DATA_Z6AP7MVP_START
  - **计时范围**：回拉仅在普通战斗运行，暂停与阶段结束时停算
  - **失败入口**：玩家PK归零后关闭本场攻击并显示重开入口
  - **重开状态**：关联【关卡配置系统】重置PK、档位、场上弹幕、待生成复读、未完成攻击与本场计时
  - **历史保留**：此前关卡已提交的圣典、败者卡和吞并内容继续保留
  - **连败记录**：本关失败时加一次，完成本关或开始新周目时清零
  DATA_Z6AP7MVP_END
  ~~~~
- scope: 7.对手PK条系统

## REQ-program-combat-stage
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#8.战斗阶段系统
- description: 8.战斗阶段系统
- acceptance:
  ~~~~text
  DATA_GGYNTLZC_START
  - **初始档位**：开局使用Tier 0，初始PK引用【各数值表】
  - **跨档处理**：一次PK变化跨过多档时连续更新至对应档位
  - **结算顺序**：收到【命中结算系统】的整发结果后再更新档位
  - **生成关联**：向【弹幕生成系统】提供当前生成、移动与寿命倍率
  - **矛盾入口**：PK满时固定在满值并停止回拉，然后转入【矛盾击破系统】
  DATA_GGYNTLZC_END
  ~~~~
- scope: 8.战斗阶段系统

## REQ-program-live-data
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#9.直播数据表现系统
- description: 9.直播数据表现系统
- acceptance:
  ~~~~text
  DATA_SG6GOM8S_START
  - **开播人数**：粉丝数乘随机倍率后取非负整数，倍率每次开播抽取一次
  - **观看变化**：正常命中和升档时增加，命中陷阱或矛盾未击破时下降
  - **点赞变化**：正常话语命中和高档位加快增长，命中陷阱时放慢增长，复读命中沿用零收益表现
  - **粉丝结算**：每场PK胜利提交一次新增粉丝，矛盾未击破也按胜利处理
  - **数值边界**：观看保持非负，点赞与评论在本场内只累计
  - **用途边界**：四项数据只用于表现，粉丝数保持跨关保存，PK与倾向及关卡解锁均独立于这些数据
  DATA_SG6GOM8S_END
  ~~~~
- scope: 9.直播数据表现系统

## REQ-program-repeat
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#10.复读系统
- description: 10.复读系统
- acceptance:
  ~~~~text
  DATA_3DLT83Q0_START
  - **普通延迟**：普通话语命中后的复读在0.5至3秒内陆续出现
  - **档位记录**：普通复读采用该发结算后的档位，等待期间保留已确定数量
  - **普通上限**：达到普通复读上限时丢弃溢出部分，容量由策划实测后配置
  - **来源统计**：分别记录普通话语复读和矛盾复读的实际生成数量，普通历史随PK胜利提交并在本场战败重开时撤回
  - **终局关联**：向【神降临系统】提供已提交普通话语的复读统计
  DATA_3DLT83Q0_END
  ~~~~
- scope: 10.复读系统

## REQ-program-contradiction-break
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#12.矛盾击破系统
- description: 12.矛盾击破系统
- acceptance:
  ~~~~text
  DATA_TEO1EZH6_START
  - **机会限制**：窗口与发射次数引用【各数值表】，未满蓄力取消不消耗发射机会
  - **即时判定**：接收【战斗攻击系统】的命中集合并在发射时判定成败
  - **成功条件**：一发中含真矛盾即为击破成功
  - **未击破条件**：仅命中假矛盾、落空或超时均为PK胜利且未击破
  - **普通奖励边界**：矛盾命中不增加普通话语的PK或倾向奖励
  - **结果提交**：成功分支由【终结神谕系统】完成后提交，未击破分支直接提交休息，两分支均保存本场普通话语记录
  DATA_TEO1EZH6_END
  ~~~~
- scope: 12.矛盾击破系统

## REQ-program-final-oracle
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#13.终结神谕系统
- description: 13.终结神谕系统
- acceptance:
  ~~~~text
  DATA_9UV73708_START
  - **候选来源**：从本场成功命中的普通话语中按原句去重
  - **候选排序**：每种倾向优先选实际普通复读最多的一句
  - **并列处理**：复读数并列时按最近命中时间再按原句标识排序
  - **候选边界**：不足三句时显示实际数量，矛盾与复读文本排除在候选之外，展示期间候选与排序保持固定
  - **选择时限**：候选可操作后开始10秒选择计时，全局暂停时一并暂停
  - **奖励提交**：手动确认与超时自动选择共用一次提交，关联【圣典系统】【败者卡系统】【吞并系统】保存本场结果
  - **倾向边界**：本版神谕选择额外倾向为零，句子继续影响圣典与终局权重
  DATA_9UV73708_END
  ~~~~
- scope: 13.终结神谕系统

## REQ-program-assimilation
- source: docs/Original/程序需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#14.吞并系统
- description: 14.吞并系统
- acceptance:
  ~~~~text
  DATA_SH2A9936_START
  - **获得条件**：接收【终结神谕系统】确认完成的击败结果
  - **结果区分**：分别保存关卡通关与真正击败记录
  - **词库继承**：向【关卡配置系统】提供已获得的可继承词库与出现权重
  - **词库边界**：矛盾专属词库继续由当前主播提供
  - **重复边界**：同一主播与同一特性只登记一次
  - **失败保留**：关联【对手PK条系统】在本场重开时保留此前吞并成果
  DATA_SH2A9936_END
  ~~~~
- scope: 14.吞并系统

## REQ-program-scripture
- source: docs/Original/程序需求汇总.md
- description: 15.圣典系统
- acceptance:
  ~~~~text
  DATA_LBTNB2O1_START
  - **记录内容**：保存关卡、主播、原句、倾向、章号与节号
  - **章节排序**：使用原关卡序号排列经文并保留缺章位置
  - **节号保存**：首次写入时随机生成一次节号，之后查看沿用同一编号
  - **空章处理**：未形成神谕的关卡保留缺章，圣典允许为空
  - **保存边界**：保留已提交经文，关卡重开时撤回本次未提交内容
  DATA_LBTNB2O1_END
  ~~~~
- scope: 15.圣典系统

## REQ-program-loser-card
- source: docs/Original/程序需求汇总.md
- description: 16.败者卡系统
- acceptance:
  ~~~~text
  DATA_85W2I8AI_START
  - **获得条件**：本场矛盾击破成功且【终结神谕系统】确认完成后发卡
  - **重复边界**：每个主播在本周目最多发放一次
  - **未击破处理**：仅赢下PK时保留历史卡片并继续流程
  - **周目保存**：退出重进或后续关卡失败时保留已提交卡片
  - **周目重置**：开始新周目时重置本周目卡片记录
  DATA_85W2I8AI_END
  ~~~~
- scope: 16.败者卡系统

## REQ-program-three-tendencies
- source: docs/Original/程序需求汇总.md
- description: 17.三项倾向系统
- acceptance:
  ~~~~text
  DATA_GRFUP8D8_START
  - **胜利保存**：本场PK胜利时提交普通话语倾向，矛盾未击破也提交
  - **失败回滚**：关联【对手PK条系统】撤回失败尝试新增的倾向
  - **并列顺序**：其余并列按正统、异端、荒谬的顺序选择并保留并列标记
  - **次要判定**：剩余最高正分项为次要倾向，并列沿用同一裁决顺序，其余均为零时采用主导倾向
  - **全零处理**：主导和次要沿用开局人设并标记无有效行为
  - **终局冻结**：进入神降临时固定最终倾向，演出输入只改变表现
  DATA_GRFUP8D8_END
  ~~~~
- scope: 17.三项倾向系统

## REQ-program-rest
- source: docs/Original/程序需求汇总.md
- description: 18.休息时刻系统
- acceptance:
  ~~~~text
  DATA_53PPFIST_START
  - **未击破分支**：PK胜利但未击破时展示对应说明并开放继续入口
  - **空内容处理**：本场无新奖励或收藏为空时展示空态并保留继续入口
  - **下一关入口**：关联【关卡配置系统】进入下一名主播的关卡
  - **最终入口**：普通关卡全部结束后进入【神降临系统】
  - **重复打开**：重新查看结算只读取已有结果，奖励继续保持一次提交
  DATA_53PPFIST_END
  ~~~~
- scope: 18.休息时刻系统

## REQ-program-divine-descent
- source: docs/Original/程序需求汇总.md
- description: 19.神降临系统
- acceptance:
  ~~~~text
  DATA_PT8R5TOO_START
  - **候选范围**：候选只取已提交的普通话语命中历史并按原句归并
  - **基础权重**：普通命中次数与对应实际复读数相加，最低取一
  - **圣典加权**：圣典句增加一次候选池最大基础权重，同句多章只加一次
  - **锁句并列**：同权重时先按首次已提交命中顺序，再按原句标识排序
  - **收束判定**：锁句完成且可见弹幕非空时，锁定原句占比达到90%后收束
  - **演出输入**：锁句后玩家输入统一强化该句的视觉与声音表现
  - **空记录处理**：圣典为空时使用普通话语历史，历史也为空时直接展示结局空态
  - **特性边界**：终局禁止生成雷弹幕，继承特性仅保留表现，锁句后保持目标原句与旧句到期时间不变
  DATA_PT8R5TOO_END
  ~~~~
- scope: 19.神降临系统

## REQ-program-ending
- source: docs/Original/程序需求汇总.md
- description: 20.结局系统
- acceptance:
  ~~~~text
  DATA_8POS721D_START
  - **教名组合**：配置三种纯倾向与六种混合倾向对应的九个教名
  - **空圣典处理**：缺章显示未形成神谕，全空时仍展示教名与判词
  - **判词分类**：分别提供一致、偏移、最高分并列和无行为记录四类判词
  - **页面组合**：将教派主图、教名、经文和判词组装成结局画面
  - **完成边界**：圣典、败者卡或吞并数量为零时仍正常完成结局
  DATA_8POS721D_END
  ~~~~
- scope: 20.结局系统

## REQ-art-identify
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#1.身份系统
- description: 1.身份系统
- acceptance:
  ~~~~text
  DATA_RU4NX65K_START
  - **主角形象**：提供主角立绘与主播头像
  - **身份图标**：提供正统、异端、荒谬对应的神明或人设图标
  - **取名界面**：提供输入框、确认按钮与背景样式
  DATA_RU4NX65K_END
  ~~~~
- scope: 1.身份系统

## REQ-art-level-configuration
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#2.关卡配置系统
- description: 2.关卡配置系统
- acceptance:
  ~~~~text
  DATA_DWIU2PIA_START
  - **主播形象**：每位主播提供立绘与头像
  - **直播主题**：每位主播提供直播间背景和粉丝牌
  - **界面变化**：提供不同主播的界面配色或局部装饰
  DATA_DWIU2PIA_END
  ~~~~
- scope: 2.关卡配置系统

## REQ-art-barrage-generation
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#3.弹幕生成系统
- description: 3.弹幕生成系统
- acceptance:
  ~~~~text
  DATA_FVO54MYB_START
  - **弹幕气泡**：提供普通弹幕的文字与气泡样式
  - **倾向标记**：提供三种倾向的颜色与小装饰
  - **舞台尺寸**：各区域设计尺寸引用【各数值表】
  DATA_FVO54MYB_END
  ~~~~
- scope: 3.弹幕生成系统

## REQ-art-barrage-traits
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#4.弹幕特性模块系统
- description: 4.弹幕特性模块系统
- acceptance:
  ~~~~text
  DATA_L88F2DCN_START
  - **特性标记**：提供每种特殊玩法的识别符号
  - **遮挡素材**：提供遮挡物的外观
  - **叠加样式**：多种特性同时出现时保持文字与标记清楚
  DATA_L88F2DCN_END
  ~~~~
- scope: 4.弹幕特性模块系统

## REQ-art-combat-attack
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#5.战斗攻击系统
- description: 5.战斗攻击系统
- acceptance:
  ~~~~text
  DATA_YTYEDQVW_START
  - **准心样式**：提供默认与瞄准状态
  - **蓄力提示**：提供蓄力过程和蓄满状态
  - **异常特效**：提供落空、遮挡和反弹反馈
  DATA_YTYEDQVW_END
  ~~~~
- scope: 5.战斗攻击系统

## REQ-art-hit-resolution
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#6.命中结算系统
- description: 6.命中结算系统
- acceptance:
  ~~~~text
  DATA_GU8JKEUI_START
  - **PK条**：提供双方拉锯的条形界面
  - **双方头像**：提供玩家与对手的端点头像
  - **高档变化**：提供高档位界面失真的素材
  DATA_GU8JKEUI_END
  ~~~~
- scope: 6.命中结算系统

## REQ-art-opponent-pk-bar
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#7.对手PK条系统
- description: 7.对手PK条系统
- acceptance:
  ~~~~text
  DATA_JM8LK4MU_START
  - **回拉反馈**：提供对手争夺PK进度的视觉提示
  - **失败画面**：提供本场失败和重开按钮样式
  - **下播表现**：提供玩家断流与对手嘲讽的画面素材
  DATA_JM8LK4MU_END
  ~~~~
- scope: 7.对手PK条系统

## REQ-art-combat-stage
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#8.战斗阶段系统
- description: 8.战斗阶段系统
- acceptance:
  ~~~~text
  DATA_OVJYRU3A_START
  - **档位界面**：提供各档位的界面状态
  - **角色状态**：提供玩家与对手逐步变化的表情或形象
  - **字体变化**：提供高档位文字强化与界面侵入的样式
  DATA_OVJYRU3A_END
  ~~~~
- scope: 8.战斗阶段系统

## REQ-art-live-data
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#9.直播数据表现系统
- description: 9.直播数据表现系统
- acceptance:
  ~~~~text
  DATA_SX6ESTZ3_START
  - **数据图标**：提供观看、点赞、评论和粉丝四种图标
  - **数据区域**：提供数字、标签与背景的排版样式
  - **热度效果**：提供高热度时数字放大和亮起的表现
  DATA_SX6ESTZ3_END
  ~~~~
- scope: 9.直播数据表现系统

## REQ-art-repeat
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#10.复读系统
- description: 10.复读系统
- acceptance:
  ~~~~text
  DATA_4ULUCBNE_START
  - **玩家粉丝牌**：复读弹幕保留清楚的玩家粉丝标记
  - **低档样式**：提供小字号、半透明的复读样式
  - **真假牌差异**：玩家粉丝牌与仿制粉丝牌保持可辨认的区别
  DATA_4ULUCBNE_END
  ~~~~
- scope: 10.复读系统

## REQ-art-contradiction-break
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#12.矛盾击破系统
- description: 12.矛盾击破系统
- acceptance:
  ~~~~text
  DATA_MQSTEURJ_START
  - **矛盾气泡**：提供真假矛盾共用的可命中样式
  - **阶段提示**：提供进入矛盾阶段的醒目标识
  - **对手状态**：提供矛盾被揭穿后的崩坏状态
  DATA_MQSTEURJ_END
  ~~~~
- scope: 12.矛盾击破系统

## REQ-art-final-oracle
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#13.终结神谕系统
- description: 13.终结神谕系统
- acceptance:
  ~~~~text
  DATA_3ODJSC94_START
  - **候选排版**：提供最多三句神谕的展示布局
  - **选择状态**：提供默认、指向和确认样式
  - **对手崩坏**：提供神谕确认后的对手崩溃画面
  DATA_3ODJSC94_END
  ~~~~
- scope: 13.终结神谕系统

## REQ-art-assimilation
- source: docs/Original/美术需求汇总.md; docs/Original/系统案_协作交付版_文本导出.md#14.吞并系统
- description: 14.吞并系统
- acceptance:
  ~~~~text
  DATA_SRBKJ0UL_START
  - **获得提示**：提供新增词库或招式的提示样式
  - **征服标记**：提供已击败主播的视觉标记
  - **来源外观**：继承弹幕保留原主播的粉丝牌或装饰
  DATA_SRBKJ0UL_END
  ~~~~
- scope: 14.吞并系统

## REQ-art-scripture
- source: docs/Original/美术需求汇总.md
- description: 15.圣典系统
- acceptance:
  ~~~~text
  DATA_6PE8DIM1_START
  - **圣典页面**：提供圣典查看界面
  - **经文排版**：提供章节、节号与正文的排版样式
  - **空章样式**：提供缺章与空圣典的展示样式
  DATA_6PE8DIM1_END
  ~~~~
- scope: 15.圣典系统

## REQ-art-loser-card
- source: docs/Original/美术需求汇总.md
- description: 16.败者卡系统
- acceptance:
  ~~~~text
  DATA_AFNHME7W_START
  - **主播卡面**：每位主播提供一张败者卡
  - **卡框**：提供统一卡框与名称位置
  - **收藏界面**：提供休息时查看卡片的页面
  DATA_AFNHME7W_END
  ~~~~
- scope: 16.败者卡系统

## REQ-art-three-tendencies
- source: docs/Original/美术需求汇总.md
- description: 17.三项倾向系统
- acceptance:
  ~~~~text
  DATA_TP1B1HFI_START
  - **倾向标识**：提供三种倾向统一的颜色、符号与装饰
  - **环境物件**：提供房间物件随倾向变化的版本
  - **教派主图**：提供对应三种倾向的教派视觉
  DATA_TP1B1HFI_END
  ~~~~
- scope: 17.三项倾向系统

## REQ-art-rest
- source: docs/Original/美术需求汇总.md
- description: 18.休息时刻系统
- acceptance:
  ~~~~text
  DATA_DXGES5I3_START
  - **结算页面**：提供本场结果与新增成果的布局
  - **休息场景**：提供卧室或其他低压场景
  - **继续按钮**：提供进入下一场或终局的入口
  DATA_DXGES5I3_END
  ~~~~
- scope: 18.休息时刻系统

## REQ-art-divine-descent
- source: docs/Original/美术需求汇总.md
- description: 19.神降临系统
- acceptance:
  ~~~~text
  DATA_MN0H328O_START
  - **镜像布局**：提供PK两端都出现玩家自己的画面
  - **终局界面**：提供高档位到崩坏的界面变化
  - **最终强调**：提供最后一句话全屏放大的画面
  DATA_MN0H328O_END
  ~~~~
- scope: 19.神降临系统

## REQ-art-ending
- source: docs/Original/美术需求汇总.md
- description: 20.结局系统
- acceptance:
  ~~~~text
  DATA_3BUWLKVM_START
  - **教派主图**：提供三种倾向对应的结局主图
  - **教名样式**：提供九种文字教名的排版或局部装饰
  - **结束转场**：提供黑屏进入圣典页的画面
  DATA_3BUWLKVM_END
  ~~~~
- scope: 20.结局系统

## REQ-original-balance
- source: docs/Original/系统案_协作交付版_文本导出.md
- description: 各数值表
- acceptance:
  ~~~~text
  DATA_ASOXN0D0_START
  基础分辨率	1920x1080	PC 先行		美术交付尺寸应大于该尺寸2倍
      准心视觉尺寸	96x96	只负责表现
      准心实际可击中区域	144x144
      手机实际可击中区域	180x180
      基础蓄力时间	0.8s	按住鼠标开始蓄力
      言弹飞行时间	0.15–0.25 s	尽量短，避免操作拖沓
      玩家PK条初始值	0.5	开局50%，正式使用Tier 0
      矛盾击破机会	1 次	限时内一发，释放时判定结果
      正常话语1命中	+0.12%	+1	倾向用颜色与装饰，强度用字重、特效或气泡框		是	强度1的弹幕	153
      正常话语2命中	+0.2%	+5	倾向用颜色与装饰，强度用字重、特效或气泡框		是	强度2的弹幕
      正常话语3命中	+0.5%	+10	倾向用颜色与装饰，强度用字重、特效或气泡框		是	强度3的弹幕
      雷弹幕命中	-0.5%	0	挂对手粉丝牌，沿用复读气泡外框		否	对手粉丝弹幕
      反击弹幕命中	-0.7%	0	有对手特殊UI的弹幕		否	对手反击弹幕
      假弹幕命中	-0.5%	0	挂仿制玩家粉丝牌，沿用复读气泡外框		否	黑粉弹幕
      言弹落空	-1%	0	言弹最终未击中任何弹幕		否	未命中任何弹幕的情况	153
      目标被遮挡	-1%	0	属于对手特殊反击手段		否	击中的区域有弹幕，但被遮挡	153
      言弹被反弹	-1%	0	拥有对手特殊UI的弹幕；属于反击弹幕的一种		否	对手反击弹幕	153
      蓄力取消：	仅按住或未蓄满松开均不消耗矛盾击破机会
      原型实测：	基础生成量、弹幕密度、同屏上限和通关时长需要实测
      生命周期取样：	生成时确定寿命，后续升降档不刷新截止时间
      异常合并：	一发中的反弹、遮挡和落空合计最多扣1个百分点
      未击破奖励：	本场没有新经文、败者卡、技能及特殊词库或特性解锁
      回拉基数：	0.005表示玩家PK每秒减少0.5个百分点
      回拉计算：	每秒减少值等于回拉基数乘当前档位倍率
  DATA_ASOXN0D0_END
  ~~~~
- scope: 基础规则表；生命周期表；核心事件表；狂热档位各区间阈值表；狂热档位弹幕规则表；对手数值表；规则补充说明

## REQ-original-audiovisual
- source: docs/Original/系统案_协作交付版_文本导出.md
- description: 音效需求；音乐需求；Juice需求
- acceptance:
  ~~~~text
  DATA_ZVRB9M0L_START
  1.身份系统
  音效需求：输入确认：提供填写名称后的确认提示音
  音乐需求：开场音乐：使用低强度菜单音乐衔接第一场直播
  Juice需求：选中反馈：选项在指向和选中时轻微放大

  2.关卡配置系统
  音效需求：主播提示：提供少量符合各主播主题的提示音
  音乐需求：直播音乐：共用可分层的音乐框架，通过音色或片段区分主播
  Juice需求：对手登场：使用连线或PK匹配的方式介绍新主播

  3.弹幕生成系统
  音效需求：入场提示：提供轻量的弹幕出现音
  音乐需求：音乐衔接：沿用直播音乐，弹幕密度变化与音乐层次同步
  Juice需求：进入效果：弹幕滑入时带少量弹性

  4.弹幕特性模块系统
  音效需求：复制提示：提供弹幕成批出现的声音
  音乐需求：音乐衔接：沿用当前直播音乐
  Juice需求：复制反馈：相似弹幕成批涌出

  5.战斗攻击系统
  音效需求：瞄准声音：提供轻量的目标提示
  音乐需求：节奏衔接：蓄满与连续命中可配合当前音乐节拍
  Juice需求：瞄准反馈：准心收紧或目标描边突出命中区域

  6.命中结算系统
  音效需求：推进声音：提供PK上涨与大幅推进的区分音
  音乐需求：音乐衔接：沿用【战斗阶段系统】控制的音乐层次
  Juice需求：条形反馈：PK变化带冲击、回弹和拖尾

  7.对手PK条系统
  音效需求：回拉氛围：提供持续的压迫提示
  音乐需求：失败音乐：失败时迅速切断直播音乐
  Juice需求：持续压力：回拉过程让玩家感到对手仍在抵抗

  8.战斗阶段系统
  音效需求：升档提示：提供档位提升的声音
  音乐需求：音乐分层：提供可逐层叠加的分轨音乐
  Juice需求：升档反馈：升档时画面和声音同时发生明显变化

  9.直播数据表现系统
  音效需求：大量点赞：提供点赞快速增加时的轻提示
  音乐需求：音乐衔接：沿用当前直播音乐
  Juice需求：数字滚动：数据变化通过连续滚动显示

  10.复读系统
  音效需求：人群声音：提供可叠加的人群跟读或赞同声
  音乐需求：音乐衔接：沿用当前阶段的直播音乐
  Juice需求：成批涌入：复读像观众接力一样陆续出现

  12.矛盾击破系统
  音效需求：阶段进入：提供进入矛盾阶段的提示音
  音乐需求：矛盾音乐：沿用当前全部音乐层并加强紧迫感
  Juice需求：阶段高潮：矛盾弹幕出现时集中增强视听反馈

  13.终结神谕系统
  音效需求：候选出现：提供文字浮出的声音
  音乐需求：选择氛围：与矛盾击破共用一次1秒静音过渡，之后保留极简底噪或持续音
  Juice需求：节奏反差：紧张直播突然停下，让选句成为焦点

  14.吞并系统
  音效需求：吞并完成：提供获得对手内容的确认音
  音乐需求：吞并：使用短过门衔接结算与休息
  Juice需求：吸收表现：对手元素并入玩家直播间
  DATA_ZVRB9M0L_END
  ~~~~
- scope: 1.身份系统；2.关卡配置系统；3.弹幕生成系统；4.弹幕特性模块系统；5.战斗攻击系统；6.命中结算系统；7.对手PK条系统；8.战斗阶段系统；9.直播数据表现系统；10.复读系统；12.矛盾击破系统；13.终结神谕系统；14.吞并系统
