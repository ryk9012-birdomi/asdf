$ErrorActionPreference = 'Stop'
$unityEditorPath = 'C:\Program Files\Unity\Hub\Editor\6000.3.11f1\Editor\Unity.exe'
if (-not (Test-Path -LiteralPath $unityEditorPath)) {
    throw 'Unity 6000.3.11f1 is not installed at the expected path. Open this folder with Unity Hub.'
}
Start-Process -FilePath $unityEditorPath -ArgumentList @('-projectPath', ('"' + $PSScriptRoot + '"'))
