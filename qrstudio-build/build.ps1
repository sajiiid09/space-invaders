$ErrorActionPreference = 'Stop'
$env:PYTHONUTF8 = '1'

# Reconstruct bundled source files from repository-safe base64 chunks.
$mainBase64 = (Get-ChildItem -Path 'payload\main_*.b64' | Sort-Object Name | ForEach-Object { Get-Content $_.FullName -Raw }) -join ''
[IO.File]::WriteAllBytes((Join-Path $PWD 'main.py'), [Convert]::FromBase64String($mainBase64))
$iconBase64 = Get-Content 'payload\icon.b64' -Raw
[IO.File]::WriteAllBytes((Join-Path $PWD 'app_icon.ico'), [Convert]::FromBase64String($iconBase64))

python -m py_compile main.py
python -m pip install --upgrade pip
pip install -r requirements.txt
python -m PyInstaller --noconfirm --clean --windowed --onedir --noupx `
  --name QRStudioPro `
  --icon app_icon.ico `
  --version-file version_info.txt `
  --add-data "app_icon.ico;." `
  --collect-all customtkinter `
  --collect-all flask `
  --collect-all werkzeug `
  --hidden-import win32com.client `
  --hidden-import win32timezone `
  --hidden-import pythoncom `
  --hidden-import pywintypes `
  --hidden-import cryptography `
  main.py

# Verify the native Windows app can start without a system Python installation.
$exePath = Join-Path $PWD 'dist\QRStudioPro\QRStudioPro.exe'
$process = Start-Process -FilePath $exePath -PassThru
Start-Sleep -Seconds 12
if ($process.HasExited) {
  throw "QRStudioPro.exe exited during startup smoke test with code $($process.ExitCode)."
}
Stop-Process -Id $process.Id -Force

$portable = Join-Path $PWD 'portable-output'
New-Item -ItemType Directory -Path $portable -Force | Out-Null
Compress-Archive -Path 'dist\QRStudioPro\*' -DestinationPath (Join-Path $portable 'QRStudioPro_Portable_v1.0.0.zip') -Force

$inno = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $inno)) {
  choco install innosetup -y --no-progress
}
& $inno QRStudioPro.iss
