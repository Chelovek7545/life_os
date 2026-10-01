$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:PUB_CACHE = Join-Path $PSScriptRoot '.tools\pub-cache'
$flutter = Join-Path $PSScriptRoot '.tools\flutter\bin\flutter.bat'
$dart = Join-Path $PSScriptRoot '.tools\flutter\bin\dart.bat'
if (!(Test-Path $flutter)) { throw 'Flutter SDK missing: install Flutter into .tools\flutter.' }
& $flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
& $dart run build_runner build
if ($LASTEXITCODE -ne 0) { throw 'Code generation failed.' }
& $flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
$release = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release'
$bundle = Join-Path $PSScriptRoot 'dist\Pulse'
New-Item -ItemType Directory -Path $bundle -Force | Out-Null
Copy-Item -Path "$release\*" -Destination $bundle -Recurse -Force
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $PSScriptRoot 'Pulse.lnk'))
$shortcut.TargetPath = Join-Path $bundle 'Pulse.exe'
$shortcut.WorkingDirectory = $bundle
$shortcut.Save()
Write-Host "Ready: $bundle\Pulse.exe"
