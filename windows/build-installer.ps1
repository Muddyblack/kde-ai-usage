# Builds AI-Usage-Setup-<version>.exe (repository root) from PyInstaller's
# "dist\AI Usage" folder with Inno Setup — see windows/installer.iss. Used by
# both workflows; run it from the repository root after
#   pyinstaller --noconfirm windows/ai-usage.spec
#
#   windows/build-installer.ps1 -Version 2.4.0
param([Parameter(Mandatory = $true)][string]$Version)
$ErrorActionPreference = "Stop"

# GitHub's Windows runners ship Inno Setup; install it anywhere else.
$iscc = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) {
    choco install innosetup -y --no-progress | Out-Null
}

# Inno Setup wants an .ico; the repository has the PNG (Pillow comes with the
# PyInstaller build step).
python -c "from PIL import Image; Image.open('readme/icon.png').convert('RGBA').save('dist/ai-usage.ico', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $iscc "/DAppVersion=$Version" "windows\installer.iss"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
