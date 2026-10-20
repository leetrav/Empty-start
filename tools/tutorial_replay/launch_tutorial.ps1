# 在独立进程中使用D盘试玩用户目录，不接触玩家原存档。
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$enginePath = 'D:\src\tools\godot-4.7.2\godot.windows.opt.tools.64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw '未找到D盘Godot4.7.2，请更新启动脚本内的引擎路径。' }
$userDataRoot = Join-Path $projectRoot '.godot\tutorial-replay-userdata'
New-Item -ItemType Directory -Force -Path $userDataRoot | Out-Null
$previousAppData = $env:APPDATA
$previousLocalData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $userDataRoot
    $env:LOCALAPPDATA = $userDataRoot
    Start-Process -FilePath $enginePath -WorkingDirectory $projectRoot -ArgumentList '--path', $projectRoot, 'res://tools/tutorial_replay/tutorial_replay.tscn', '--log-file', (Join-Path $projectRoot '.godot\tutorial-replay.log')
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalData
}
