$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$distRoot = Join-Path $root 'dist\windows-portable'
$distDir = Join-Path $distRoot 'Memorylux'
$zipPath = Join-Path $root 'dist\memorylux-windows-portable.zip'

Write-Host 'Compilando Memorylux en Windows Release...'
Push-Location $root
try {
    flutter build windows --release
} finally {
    Pop-Location
}

if (!(Test-Path $releaseDir)) {
    throw "No se encontro la carpeta de salida esperada: $releaseDir"
}

if (Test-Path $distRoot) {
    Remove-Item $distRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $distDir | Out-Null

Write-Host 'Copiando archivos del build portable...'
Copy-Item (Join-Path $releaseDir '*') $distDir -Recurse -Force

$launcherPath = Join-Path $distRoot 'Iniciar Memorylux.bat'
@'
@echo off
setlocal
cd /d "%~dp0\Memorylux"
start "" "memorylux.exe"
'@ | Set-Content -Encoding ASCII $launcherPath

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host 'Generando ZIP portable...'
Compress-Archive -Path (Join-Path $distRoot '*') -DestinationPath $zipPath -Force

Write-Host ''
Write-Host "Listo:"
Write-Host "  Carpeta portable: $distRoot"
Write-Host "  ZIP portable:     $zipPath"
