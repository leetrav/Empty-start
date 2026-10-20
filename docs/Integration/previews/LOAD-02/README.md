# LOAD-02 实机证据

代码5ebf7d7，Godot4.7.2 Steam / Windows D3D12 Forward+ / RTX3050 Laptop，1280×720真实GUI。live_loading.png为原加载层在正式开播前的实际Viewport截图，无加工。

runtime.log：LIVE_LOADING_DONE failures=0 checked_covers=6，四个正式关卡均从真实房间开播；另覆盖首关真实PK失败并等待失败演出后的鼠标重开、暂停菜单重开，验证提示、单次重建、树暂停和PK冻结。测试预载正式GAME PackedScene，证明暖缓存也显示，不冒充冷加载或人工全通关。

global_regression.log：GLOBAL_LOADING_DONE failures=0；缺失路径与TEST_ONLY_invalid_packed_scene相关ERROR是主动注入的恢复验证，详情见LOAD-02日志。

仅本地保存，用户要求PR暂缓；未在其他设备或导出包验收。
