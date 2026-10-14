# INT-12 V0 整局复验 · 2026-10-14

Godot 4.7.2.stable.steam.ed1daf0bf，Windows D3D12 / Forward+，1152×648。

原始测试命令：`godot.windows.opt.tools.64.exe --path <隔离工作树> res://tests/integration/int_04_full_run.tscn --resolution 1152x648 --quit-after 9000 --log-file <隔离日志>`

测试时隔离副本的 SaveManager SAVE_PATH 临时使用 `res://.godot/pr224_int04_save.res`，没有触及用户的存档。测试脚本适配ID-13爪印/漫画/房间转场和CB-13六固定候选；适配已提交本PR。脚本外的临时存档路径修改未提交。自然2～4分钟试玩、Android待验收。

```text
Godot Engine v4.7.2.stable.steam.ed1daf0bf - https://godotengine.org
D3D12 12_0 - Forward+ - Using Device #0: AMD - AMD Radeon(TM) Graphics

INT04 ROUTE BEGIN empty_history=false
INT04 aim target=(1355.0, 501.4463) raw_input=(813.0001, 300.8678) viewport_mouse=(2266.667, 6.666656) actual_aim=(1355.0, 501.4463)
INT04 before release held=true full=true phase=0
INT04 shot targets=[130962950702] expected=130962950702 facts=[]
INT04 LEVEL BEGIN empty_history=false level=0
INT04 aim target=(1212.833, 1050.5) raw_input=(727.6998, 630.3) viewport_mouse=(2266.667, 6.666656) actual_aim=(1212.833, 1050.5)
INT04 before release held=true full=true phase=0
INT04 shot targets=[139536107804] expected=139536107804 facts=[]
INT04 aim target=(897.0, 301.5) raw_input=(538.2, 180.9) viewport_mouse=(2266.667, 6.666656) actual_aim=(897.0, 301.5)
INT04 before release held=true full=true phase=0
INT04 shot targets=[143814298049] expected=143814298049 facts=[{ "target_instance_id": 143814298049, "original_sentence_id": "test_contra_true_01", "original_sentence_text": "我从未删过评论，但所有评论都被我删除。" }]
INT04 aim target=(960.0, 576.0) raw_input=(576.0, 345.6) viewport_mouse=(2266.667, 6.666656) actual_aim=(960.0, 576.0)
INT04 before release held=true full=true phase=0
INT04 shot targets=[152387455637] expected=152387455637 facts=[]
INT04 LEVEL BEGIN empty_history=false level=1
INT04 aim target=(589.0, 1036.806) raw_input=(353.4, 622.0837) viewport_mouse=(2266.667, 6.666656) actual_aim=(589.0, 1036.806)
INT04 before release held=true full=true phase=0
INT04 shot targets=[160641845911] expected=160641845911 facts=[]
INT04 aim target=(801.0, 301.5) raw_input=(480.6, 180.9) viewport_mouse=(2266.667, 6.666656) actual_aim=(801.0, 301.5)
INT04 before release held=true full=true phase=0
INT04 shot targets=[166144772550] expected=166144772550 facts=[{ "target_instance_id": 166144772550, "original_sentence_id": "test_contra_false_02", "original_sentence_text": "请再发一次刚才的弹幕。" }]
INT04 ROUTE PASS empty_history=false facts={ "identity": &"identity_orthodox_1", "fans": 14, "tendency": [6, 0, 0], "history": [{ "original_sentence_id": "test_word_01", "tendency": "orthodox", "hit_count": 1, "first_committed_hit_order": 1 }, { "original_sentence_id": "test_word_09", "tendency": "orthodox", "hit_count": 1, "first_committed_hit_order": 2 }], "scripture": 1, "cards": 1, "assimilation": { "inherited_word_weights": { &"test_int04_pool_test_level_01": 1.0 }, "inherited_trait_ids": [&"occlusion"] } }
INT04 ROUTE BEGIN empty_history=true
INT04 LEVEL BEGIN empty_history=true level=0
INT04 aim target=(777.0, 301.5) raw_input=(466.2, 180.9) viewport_mouse=(2266.667, 6.666656) actual_aim=(777.0, 301.5)
INT04 before release held=true full=true phase=0
INT04 shot targets=[212802210226] expected=212802210226 facts=[{ "target_instance_id": 212802210226, "original_sentence_id": "test_contra_false_01", "original_sentence_text": "今天直播间非常吵。" }]
INT04 LEVEL BEGIN empty_history=true level=1
INT04 aim target=(801.0, 301.5) raw_input=(480.6, 180.9) viewport_mouse=(2266.667, 6.666656) actual_aim=(801.0, 301.5)
INT04 before release held=true full=true phase=0
INT04 shot targets=[224076499386] expected=224076499386 facts=[{ "target_instance_id": 224076499386, "original_sentence_id": "test_contra_false_02", "original_sentence_text": "请再发一次刚才的弹幕。" }]
INT04 ROUTE PASS empty_history=true facts={ "identity": &"identity_orthodox_1", "fans": 14, "tendency": [0, 0, 0], "history": [], "scripture": 0, "cards": 0, "assimilation": { "inherited_word_weights": {  }, "inherited_trait_ids": [] } }
PASS INT-04 full run checks=96 top_level_routes=10 DD_completed=1
```
