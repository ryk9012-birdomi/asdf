param(
    [string]$GodotPath = $env:GODOT_BIN,
    [switch]$Run,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
if ($Run -and $Test) { throw 'Choose either -Run or -Test.' }
$projectPath = Join-Path $PSScriptRoot 'godot'
if (-not $GodotPath) {
    $localRuntime = Join-Path $env:LOCALAPPDATA 'Godot\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
    if (Test-Path -LiteralPath $localRuntime) {
        $GodotPath = $localRuntime
    } else {
        $installedGodot = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($installedGodot) { $GodotPath = $installedGodot.Source }
    }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot 4.7.2 is required. Pass -GodotPath <exe> or set GODOT_BIN. https://godotengine.org/download/windows/'
}

if ($Test) {
    # Godot may return exit code 0 after a GDScript runtime error.
    function Invoke-GodotCheck([string[]]$CheckArguments) {
        $checkOutput = & $GodotPath @CheckArguments 2>&1
        $checkExitCode = $LASTEXITCODE
        $checkOutput | ForEach-Object { Write-Output $_ }
        if ($checkExitCode -ne 0 -or ($checkOutput -match '(SCRIPT ERROR:|ERROR:)')) {
            throw 'Godot validation failed. See the engine output above.'
        }
    }
    Invoke-GodotCheck @('--headless', '--path', $projectPath, '--editor', '--import')
    Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/test_character_system.gd')
    Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/test_battle.gd')
    Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/test_flow.gd')
    exit 0
}

$launchArguments = @('--path', ('"{0}"' -f $projectPath))
if (-not $Run) { $launchArguments += '--editor' }
Start-Process -FilePath $GodotPath -ArgumentList $launchArguments -WindowStyle Hidden
