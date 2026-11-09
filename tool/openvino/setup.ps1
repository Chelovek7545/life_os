param(
    [string]$Python = '',
    [switch]$DownloadModel
)
$ErrorActionPreference = 'Stop'
$assistantRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$assistantVenv = Join-Path $assistantRoot '.venv-openvino'
$assistantPython = Join-Path $assistantVenv 'Scripts\python.exe'
$assistantRuntime = Join-Path $assistantRoot '.openvino-runtime'
if ($Python) {
    & $Python -c "import sys; assert (3,10) <= sys.version_info[:2] < (3,14), 'Use Python 3.10-3.13 (64-bit)'; assert sys.maxsize > 2**32, 'Use 64-bit Python'"
    if ($LASTEXITCODE -ne 0) { throw 'Python 3.10-3.13 (64-bit) is required.' }
    if (-not (Test-Path -LiteralPath $assistantPython)) {
        & $Python -m venv $assistantVenv
        if ($LASTEXITCODE -ne 0) { throw 'Failed to create the OpenVINO environment.' }
    }
    & $assistantPython -m pip install -r (Join-Path $PSScriptRoot 'requirements.txt')
} else {
    $assistantUvDirectory = Join-Path $assistantRuntime 'uv'
    $assistantUv = Join-Path $assistantUvDirectory 'uv.exe'
    if (-not (Test-Path -LiteralPath $assistantUv)) {
        New-Item -ItemType Directory -Path $assistantUvDirectory -Force | Out-Null
        $assistantArchive = Join-Path $assistantUvDirectory 'uv.zip'
        $assistantHash = Join-Path $assistantUvDirectory 'uv.zip.sha256'
        $assistantUrl = 'https://github.com/astral-sh/uv/releases/download/0.9.5/uv-x86_64-pc-windows-msvc.zip'
        Invoke-WebRequest -Uri $assistantUrl -OutFile $assistantArchive -TimeoutSec 180
        Invoke-WebRequest -Uri ($assistantUrl + '.sha256') -OutFile $assistantHash -TimeoutSec 30
        $assistantExpected = ((Get-Content -LiteralPath $assistantHash -Raw).Trim() -split '\s+')[0]
        if ((Get-FileHash -LiteralPath $assistantArchive -Algorithm SHA256).Hash -ne $assistantExpected) { throw 'uv checksum mismatch' }
        Expand-Archive -LiteralPath $assistantArchive -DestinationPath $assistantUvDirectory -Force
    }
    # The interpreter must survive flutter clean, so keep it outside .dart_tool.
    $env:UV_PYTHON_INSTALL_DIR = Join-Path $assistantRuntime 'python'
    $env:UV_CACHE_DIR = Join-Path $assistantRoot '.dart_tool\uv-cache'
    & $assistantUv venv --allow-existing --python 3.12 --managed-python $assistantVenv
    if ($LASTEXITCODE -ne 0) { throw 'Failed to prepare isolated Python.' }
    & $assistantUv pip install --python $assistantPython -r (Join-Path $PSScriptRoot 'requirements.txt')
}
if ($LASTEXITCODE -ne 0) { throw 'Failed to install OpenVINO dependencies.' }
& $assistantPython -c "import os, sys, openvino as ov; print('Available devices:', ov.Core().available_devices, flush=True); os._exit(0)"
if ($LASTEXITCODE -ne 0) { throw 'OpenVINO initialization failed.' }
$assistantModel = Join-Path $assistantRoot 'models\Qwen2.5-1.5B-Instruct-int4-ov'
if ($DownloadModel) {
    & $assistantPython (Join-Path $PSScriptRoot 'download_model.py') --output $assistantModel
    if ($LASTEXITCODE -ne 0) { throw 'Model download did not finish; run again to resume.' }
}
Write-Output "Python: $assistantPython"
Write-Output "Model:  $assistantModel"
Write-Output 'Open Life OS, expand the chat, and enter these paths in model settings. Select NPU explicitly.'
