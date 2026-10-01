# Proviyaa POS Windows Launcher
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path "$ScriptDir\..").Path
$EnvFile = if ($env:PROVIYAA_ENV_FILE) { $env:PROVIYAA_ENV_FILE } else { Join-Path $ProjectRoot ".env.local" }

if (-not (Test-Path $EnvFile)) {
    Write-Error "Missing $EnvFile`nCopy .env.local.example to .env.local and fill local-safe values."
    exit 1
}

$AllowedKeys = @('APP_ENV', 'DATA_MODE', 'PROVIYAA_API_BASE_URL', 'SYNC_ENABLED')
# Supabase settings belong to the backend (backend/.env) now; the app never
# receives them. Old .env.local files still carrying them are tolerated.
$BackendOnlyKeys = @('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY')
$DartDefines = @()

Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    if (-not ($line -match '^([^=]+)=(.*)$')) {
        Write-Error "Invalid env line (expected KEY=VALUE): $line"
        exit 1
    }
    $key = $Matches[1].Trim()
    $value = $Matches[2].Trim()
    if ($BackendOnlyKeys -contains $key) {
        Write-Warning "Ignoring $key — Supabase settings go in backend/.env; the app talks only to PROVIYAA_API_BASE_URL."
    } elseif ($AllowedKeys -contains $key) {
        $DartDefines += "--dart-define=$key=$value"
    } else {
        Write-Error "Refusing unsupported or secret env key: $key"
        exit 1
    }
}

Push-Location $ProjectRoot
try {
    $targetArgs = @($args)
    $isWindowsTarget = $targetArgs -contains 'windows'

    if (-not $isWindowsTarget) {
        $chromeProfile = Join-Path $ProjectRoot ".chrome_dev_data"
        if (-not (Test-Path $chromeProfile)) {
            New-Item -ItemType Directory -Path $chromeProfile -Force | Out-Null
        }
        if ($targetArgs.Length -eq 0) {
            $targetArgs = @('-d', 'chrome', '--web-port=7988', "--web-browser-flag=--user-data-dir=$chromeProfile")
        } else {
            if (-not ($targetArgs -contains '-d')) {
                $targetArgs = @('-d', 'chrome') + $targetArgs
            }
            if (-not ($targetArgs -join ' ' -match '--web-port')) {
                $targetArgs += '--web-port=7988'
            }
            if (-not ($targetArgs -join ' ' -match '--user-data-dir')) {
                $targetArgs += "--web-browser-flag=--user-data-dir=$chromeProfile"
            }
        }
    }

    $allArgs = @('run') + $DartDefines + $targetArgs
    Write-Host "Running: flutter $($allArgs -join ' ')" -ForegroundColor Cyan
    & flutter @allArgs
} finally {
    Pop-Location
}
