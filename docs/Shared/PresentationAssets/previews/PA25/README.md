# PA-25 真实Godot运行证据

代码提交：d2c29a1f32500ab4d3f5efaff9e5ff015943df81 。2026-10-20，本地工作区D:/src/Empty-start-fixes-20261020。

- original_1920.png / standard_1920.png：Compatibility，1920×1080，同一光效时间6秒，固定标题姿态。
- default_original_1920.png / default_standard_1920.png：工程默认D3D12 Forward+，1920×1080，同样固定条件。
- settings_1280.png：1280×720设置面板，新增标题光效三档，控件完整可见。
- comparison.json / benchmark.log：Compatibility原始采样汇总，含主视口和光效视口GPU时间、墙钟帧时及色差/设置验证。
- default-renderer.json / default-renderer.log：D3D12同流程；GPU整页中位数1080p约降54%，720p约降44%。
- pause-regression.log：六页面Esc、结局全屏下通过设置退出全屏等回归通过。

每组预热300帧，采样1200帧，关闭VSync/帧率限制，RTX3050 Laptop。短时单机结果，策划设备待测。具体边界和后续见PA-25日志。
