$ErrorActionPreference = 'Stop'
$env:PYTHONUTF8 = '1'
$diagnosticPath = Join-Path $PWD 'build-diagnostic.txt'

function Write-Stage([string]$message) {
  $line = "[$(Get-Date -Format o)] $message"
  Write-Host $line
  Add-Content -Path $diagnosticPath -Value $line
}

function Invoke-LoggedCommand([string]$name, [string]$command, [string]$logFile) {
  cmd.exe /d /c "$command > `"$logFile`" 2>&1"
  $exitCode = $LASTEXITCODE
  if (Test-Path $logFile) {
    Get-Content $logFile | ForEach-Object { Write-Host $_ }
  }
  if ($exitCode -ne 0) {
    if (Test-Path $logFile) {
      Add-Content -Path $diagnosticPath -Value "`r`n--- $name output ---"
      Get-Content $logFile | Add-Content -Path $diagnosticPath
    }
    throw "$name failed with exit code $exitCode."
  }
}

try {
  Write-Stage 'Reconstructing verified Python source and icon'
  $prefixFiles = 0..6 | ForEach-Object { Join-Path $PWD ("payload\main_{0:D2}.b64" -f $_) }
  $prefixBase64 = ($prefixFiles | ForEach-Object { [IO.File]::ReadAllText($_) }) -join ''
  $mainPath = Join-Path $PWD 'main.py'
  [IO.File]::WriteAllBytes($mainPath, [Convert]::FromBase64String($prefixBase64))
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  Get-ChildItem -Path 'payload\tail_*.txt' | Sort-Object Name | ForEach-Object {
    $tailText = [IO.File]::ReadAllText($_.FullName).Replace("`r`n", "`n").Replace("`r", "`n")
    [IO.File]::AppendAllText($mainPath, $tailText, $utf8NoBom)
  }
  $sourceHash = (Get-FileHash -Algorithm SHA256 $mainPath).Hash.ToLowerInvariant()
  Add-Content -Path $diagnosticPath -Value "Source SHA256: $sourceHash"
  if ($sourceHash -ne '4f4175abb862c6547c013c4d4b99171f71082008beabf894aa429889357dc695') {
    throw "Reconstructed source checksum mismatch: $sourceHash"
  }

  $iconBase64 = Get-Content 'payload\icon.b64' -Raw
  [IO.File]::WriteAllBytes((Join-Path $PWD 'app_icon.ico'), [Convert]::FromBase64String($iconBase64))

  Write-Stage 'Checking Python source syntax'
  Invoke-LoggedCommand 'Python syntax check' 'python -m py_compile main.py' 'syntax.log'

  Write-Stage 'Installing build dependencies'
  Invoke-LoggedCommand 'pip upgrade' 'python -m pip install --upgrade pip' 'pip-upgrade.log'
  Invoke-LoggedCommand 'Dependency installation' 'python -m pip install -r requirements.txt' 'pip-install.log'

  Write-Stage 'Generating multi-resolution installer icon'
  Invoke-LoggedCommand 'Installer icon generation' 'python make_icon.py' 'icon-generation.log'

  Write-Stage 'Building standalone Windows application'
  $pyInstallerCommand = 'python -m PyInstaller --noconfirm --clean --windowed --onedir --noupx --name QRStudioPro --icon app_icon.ico --version-file version_info.txt --add-data "app_icon.ico;." --collect-all customtkinter --collect-all flask --collect-all werkzeug --hidden-import win32com.client --hidden-import win32timezone --hidden-import pythoncom --hidden-import pywintypes --hidden-import cryptography main.py'
  Invoke-LoggedCommand 'PyInstaller' $pyInstallerCommand 'pyinstaller.log'

  Get-ChildItem -Path 'dist' -Recurse -ErrorAction SilentlyContinue | Select-Object FullName,Length | Format-Table -AutoSize | Out-String | Add-Content -Path $diagnosticPath

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
    Invoke-LoggedCommand 'Inno Setup installation' 'choco install innosetup -y --no-progress' 'inno-install.log'
  }
  $innoProcess = Start-Process -FilePath $inno -ArgumentList 'QRStudioPro.iss' -NoNewWindow -Wait -PassThru -RedirectStandardOutput 'inno-build.log' -RedirectStandardError 'inno-build-error.log'
  Get-Content 'inno-build.log' -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
  Get-Content 'inno-build-error.log' -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
  if ($innoProcess.ExitCode -ne 0) { throw "Inno Setup compiler failed with exit code $($innoProcess.ExitCode)." }

  Write-Stage 'BUILD SUCCESS'
}
catch {
  $details = $_ | Format-List * -Force | Out-String
  Add-Content -Path $diagnosticPath -Value "BUILD FAILURE`r`n$details"
  Write-Error $details
  exit 1
}
