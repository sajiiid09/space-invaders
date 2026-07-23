$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$env:PYTHONUTF8 = '1'
$diagnosticPath = Join-Path $PWD 'build-diagnostic.txt'

function Write-Stage([string]$message) {
  $line = "[$(Get-Date -Format o)] $message"
  Write-Host $line
  Add-Content -Path $diagnosticPath -Value $line
}

try {
  Write-Stage 'Reconstructing Python source and icon'
  $mainBase64 = (Get-ChildItem -Path 'payload\main_*.b64' | Sort-Object Name | ForEach-Object { Get-Content $_.FullName -Raw }) -join ''
  [IO.File]::WriteAllBytes((Join-Path $PWD 'main.py'), [Convert]::FromBase64String($mainBase64))
  $iconBase64 = Get-Content 'payload\icon.b64' -Raw
  [IO.File]::WriteAllBytes((Join-Path $PWD 'app_icon.ico'), [Convert]::FromBase64String($iconBase64))

  Write-Stage 'Checking Python source syntax'
  python -m py_compile main.py

  Write-Stage 'Installing build dependencies'
  python -m pip install --upgrade pip
  python -m pip install -r requirements.txt

  Write-Stage 'Building standalone Windows application'
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

  Write-Stage 'Running Windows startup smoke test'
  $exePath = Join-Path $PWD 'dist\QRStudioPro\QRStudioPro.exe'
  if (-not (Test-Path $exePath)) { throw "Built executable was not found: $exePath" }
  $process = Start-Process -FilePath $exePath -PassThru
  Start-Sleep -Seconds 12
  if ($process.HasExited) {
    throw "QRStudioPro.exe exited during startup smoke test with code $($process.ExitCode)."
  }
  Stop-Process -Id $process.Id -Force

  Write-Stage 'Creating portable ZIP'
  $portable = Join-Path $PWD 'portable-output'
  New-Item -ItemType Directory -Path $portable -Force | Out-Null
  Compress-Archive -Path 'dist\QRStudioPro\*' -DestinationPath (Join-Path $portable 'QRStudioPro_Portable_v1.0.0.zip') -Force

  Write-Stage 'Creating professional installer'
  $inno = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
  if (-not (Test-Path $inno)) {
    choco install innosetup -y --no-progress
  }
  & $inno QRStudioPro.iss

  Write-Stage 'BUILD SUCCESS'
}
catch {
  $details = $_ | Format-List * -Force | Out-String
  Add-Content -Path $diagnosticPath -Value "BUILD FAILURE`r`n$details"
  Write-Error $details
  exit 1
}
