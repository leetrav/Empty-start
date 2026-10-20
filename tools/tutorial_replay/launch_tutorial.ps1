# 在独立进程中使用D盘试玩用户目录，不接触玩家原存档。
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
# 优先使用显式指定路径，其次常见安装位置；不要求每台机器都使用同一目录。
$engineCandidates = @(
    $env:GODOT_BIN,
    'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    'D:\src\tools\godot-4.7.2\godot.windows.opt.tools.64.exe'
)
$engineCommand = Get-Command 'godot.windows.opt.tools.64.exe' -ErrorAction SilentlyContinue
if ($engineCommand) { $engineCandidates += $engineCommand.Source }
$enginePath = $engineCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if (-not $enginePath) { throw '未找到 Godot 4.7.2。请设置 GODOT_BIN 为 godot.windows.opt.tools.64.exe 的完整路径。' }
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
