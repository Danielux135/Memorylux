$ErrorActionPreference = 'Stop'

$JdkDir = 'C:\Program Files\Eclipse Adoptium\jdk-21.0.8.9-hotspot'
$env:JAVA_HOME = $JdkDir
$env:Path = (Join-Path $JdkDir 'bin') + ';' + $env:Path

$DeviceId = $null
try {
    $devices = flutter devices --machine | ConvertFrom-Json
    $androidDevice = $devices | Where-Object { $_.targetPlatform -like 'android*' } | Select-Object -First 1
    if ($androidDevice) {
        $DeviceId = $androidDevice.id
    }
} catch {
    $DeviceId = $null
}

if (-not $DeviceId) {
    $DeviceId = '9PTCZHIFW4GMWCJZ'
}

Write-Host 'Cleaning build outputs...'
flutter clean

Write-Host 'Building release APK...'
flutter build apk --release

Write-Host 'Installing on connected device...'
flutter install -d $DeviceId
