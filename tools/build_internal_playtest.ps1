# Internal Windows/Android playtest builds. Godot 4.7.2, local machine.
[CmdletBinding()]
param(
    [ValidateSet('Windows', 'Android', 'Both')]
    [string] $Platform = 'Windows',
    [string] $DestinationRoot = 'D:\tmp',
    [string] $GodotEditor = 'D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [switch] $SkipSmoke
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$project = Split-Path -Parent $PSScriptRoot
if (!(Test-Path -LiteralPath $GodotEditor)) { throw "Godot editor not found: $GodotEditor" }
if (!(Test-Path -LiteralPath (Join-Path $project 'export_presets.cfg'))) { throw 'Missing export_presets.cfg' }
if (!(Test-Path -LiteralPath $DestinationRoot)) { New-Item -Path $DestinationRoot -ItemType Directory -Force | Out-Null }

# Godot writes non-fatal resource-cleanup notices to stderr even with export exit 0.
# Capture stderr to a diagnostic file and decide success by the actual process exit code.
function Invoke-BuildProcess([string] $label, [string] $program, [string[]] $arguments, [string] $transcript) {
    # Windows Godot is a GUI-subsystem executable: use -Wait, not bare &,
    # because PowerShell can otherwise return before the export file is finalized.
    $commandLine = ($arguments | ForEach-Object {
        $item = $_.Replace('"', '\"')
        if ($item -match '\s') { '"' + $item + '"' } else { $item }
    }) -join ' '
    $outPath = $transcript + '.stdout'
    $errPath = $transcript + '.stderr'
    $proc = Start-Process -FilePath $program -ArgumentList $commandLine -Wait -PassThru -RedirectStandardOutput $outPath -RedirectStandardError $errPath -ErrorAction Stop
    if ($proc.ExitCode -ne 0) {
        Write-Host ('FAILED ' + $label + ', exit=' + $proc.ExitCode)
        Get-Content -LiteralPath $errPath -Tail 20 -ErrorAction SilentlyContinue
        throw ('Process failed: ' + $label + ', exit=' + $proc.ExitCode)
    }
    Write-Host ('PASS ' + $label)
}
function Get-ArtifactRecord([string] $path) {
    $item = Get-Item -LiteralPath $path -ErrorAction Stop
    if ($item.Length -lt 1024) { throw ('Output unexpectedly small: ' + $path) }
    return [ordered]@{
        filename = $item.Name
        bytes = $item.Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    }
}

# 导出成功只说明 Godot 能生成文件；正式内容不齐时必须在创建包目录前终止。
$preflightDirectory = Join-Path $DestinationRoot ('INT-15_Preflight_' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -Path $preflightDirectory -ItemType Directory -ErrorAction Stop | Out-Null
$preflightLog = Join-Path $preflightDirectory 'production_catalog.log'
Invoke-BuildProcess 'Godot project import for production preflight' $GodotEditor @(
    '--headless', '--editor', '--path', $project, '--import',
    '--log-file', (Join-Path $preflightDirectory 'godot_import.log')
) (Join-Path $preflightDirectory 'godot_import_cli.log')
Invoke-BuildProcess 'production catalog preflight' $GodotEditor @(
    '--headless', '--path', $project, '--quit-after', '2',
    '--script', 'res://tests/integration/int_15_production_catalog_preflight.gd',
    '--log-file', $preflightLog
) (Join-Path $preflightDirectory 'production_catalog_cli.log')
if (!(Select-String -LiteralPath (Join-Path $preflightDirectory 'production_catalog_cli.log.stdout') -SimpleMatch 'PASS INT-15 production catalog' -Quiet)) {
    throw 'Production catalog preflight exited successfully without its PASS record'
}

$buildDir = Join-Path $DestinationRoot ('GameJam_InternalPlaytest_' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -Path $buildDir -ItemType Directory -ErrorAction Stop | Out-Null
$commit = (& git -C $project rev-parse HEAD).Trim()
$report = [ordered]@{
    kind = 'internal-playtest'
    build_time = (Get-Date).ToString('o')
    git_commit = $commit
    engine = 'Godot 4.7.2'
    production_catalog_preflight = 'passed'
    artifacts = @{}
}

if ($Platform -in @('Windows', 'Both')) {
    $exe = Join-Path $buildDir 'GameJam_Playtest.exe'
    $pck = Join-Path $buildDir 'GameJam_Playtest.pck'
    $exportLog = Join-Path $buildDir 'windows_export.log'
    Write-Host '[Windows] Export release...'
    Invoke-BuildProcess 'Windows export' $GodotEditor @(
        '--headless', '--path', $project, '--export-release', 'Windows Desktop',
        $exe, '--log-file', $exportLog
    ) (Join-Path $buildDir 'windows_export_cli.log')
    if (!(Test-Path -LiteralPath $exe) -or !(Test-Path -LiteralPath $pck)) { throw 'Missing EXE/PCK after export' }

    $smokeStatus = 'skipped'
    if (!$SkipSmoke) {
        $previousAppData = $env:APPDATA
        $smokeData = Join-Path $buildDir 'smoke_userdata'
        New-Item -Path $smokeData -ItemType Directory -Force | Out-Null
        try {
            $env:APPDATA = $smokeData
            Push-Location $buildDir
            try {
                Write-Host '[Windows] Smoke-test exported game...'
                $smokeLog = Join-Path $buildDir 'windows_smoke.log'
                Invoke-BuildProcess 'Windows smoke' $exe @(
                    '--headless', '--quit-after', '300', '--log-file', $smokeLog
                ) (Join-Path $buildDir 'windows_smoke_cli.log')
            } finally { Pop-Location }
        } finally { $env:APPDATA = $previousAppData }
        if (!(Test-Path -LiteralPath $smokeLog)) { throw 'Missing smoke log' }
        if (Select-String -LiteralPath $smokeLog -Pattern 'SCRIPT ERROR|ERROR:' -Quiet) {
            throw 'Windows smoke log contains runtime errors'
        }
        $smokeStatus = 'passed'
    }

    $stage = Join-Path $buildDir 'Windows_Release'
    New-Item -Path $stage -ItemType Directory -ErrorAction Stop | Out-Null
    Copy-Item -LiteralPath $exe, $pck -Destination $stage -ErrorAction Stop
    $engineLicense = Join-Path (Split-Path -Parent $GodotEditor) 'LICENSE.txt'
    if (Test-Path -LiteralPath $engineLicense) {
        Copy-Item -LiteralPath $engineLicense -Destination (Join-Path $stage 'Godot_ENGINE_LICENSE.txt') -ErrorAction Stop
    }
    $instructions = @(
        '2026 TapTap GameJam - Internal Playtest'
        ('Source commit: ' + $commit)
        'Windows 10/11 x64: Unzip ALL files then run GameJam_Playtest.exe.'
        'Keep GameJam_Playtest.pck in the SAME folder as GameJam_Playtest.exe.'
        'First launch may play the opening comic, followed by the main menu.'
        'Internal build only. Please report reproduction steps and screenshots for bugs.'
    )
    [System.IO.File]::WriteAllLines((Join-Path $stage 'README_PLAYTEST.txt'), $instructions, [System.Text.UTF8Encoding]::new($false))
    $winInfo = [ordered]@{
        exe = Get-ArtifactRecord $exe
        pck = Get-ArtifactRecord $pck
        smoke = $smokeStatus
    }
    $winInfo | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $stage 'manifest.json') -Encoding UTF8
    $zip = Join-Path $buildDir 'GameJam_InternalPlaytest_win64.zip'
    Write-Host '[Windows] Compressing ZIP...'
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal -ErrorAction Stop
    if (!(Test-Path -LiteralPath $zip)) { throw 'Windows ZIP not created' }
    $report.artifacts.windows = [ordered]@{ zip = Get-ArtifactRecord $zip; details = $winInfo }
}

if ($Platform -in @('Android', 'Both')) {
    $apk = Join-Path $buildDir 'GameJam_Playtest_Android_debug.apk'
    Write-Host '[Android] Export ARM64 debug APK...'
    Invoke-BuildProcess 'Android export' $GodotEditor @(
        '--headless', '--path', $project, '--export-debug', 'Android',
        $apk, '--log-file', (Join-Path $buildDir 'android_export.log')
    ) (Join-Path $buildDir 'android_export_cli.log')
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $apkZip = [System.IO.Compression.ZipFile]::OpenRead($apk)
    try {
        $contents = @($apkZip.Entries | ForEach-Object { $_.FullName })
        if ($contents -notcontains 'AndroidManifest.xml') { throw 'APK missing AndroidManifest.xml' }
        if (@($contents | Where-Object { $_ -like 'lib/arm64-v8a/*' }).Count -eq 0) {
            throw 'APK missing ARM64 native libraries'
        }
    } finally { $apkZip.Dispose() }
    $report.artifacts.android = [ordered]@{
        apk = Get-ArtifactRecord $apk
        abi = 'arm64-v8a'
        signing = 'debug'
        physical_device_test = 'not_run'
    }
}

$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $buildDir 'build_manifest.json') -Encoding UTF8
Write-Host ('BUILD_OK ' + $buildDir)
Write-Host ('SOURCE_COMMIT ' + $commit)
Get-ChildItem -LiteralPath $buildDir -File | Select-Object Name, Length | Format-Table -AutoSize
