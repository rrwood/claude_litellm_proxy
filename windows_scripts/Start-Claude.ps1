# Start-Claude.ps1
# Loads environment variables from a .env file then launches Claude Code.
# Place this script and your .env file anywhere in your PATH.

param(
    [string]$EnvFile = ".env"
)

# ── Locate .env file ───────────────────────────────────────────────────────────
# Check current directory first, then the script's own directory
$envPath = $null

if (Test-Path (Join-Path (Get-Location) $EnvFile)) {
    $envPath = Join-Path (Get-Location) $EnvFile
} elseif (Test-Path (Join-Path $PSScriptRoot $EnvFile)) {
    $envPath = Join-Path $PSScriptRoot $EnvFile
}

if (-not $envPath) {
    Write-Warning "No .env file found in current directory or script directory. Starting Claude without extra environment."
} else {
    Write-Host "Loading environment from: $envPath" -ForegroundColor Cyan

    Get-Content $envPath | ForEach-Object {
        $line = $_.Trim()

        # Skip blank lines and comments
        if ($line -eq "" -or $line.StartsWith("#")) { return }

        # Split on first = only
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { return }

        $key   = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()

        # Strip surrounding quotes if present
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
        Write-Host "  Set $key" -ForegroundColor DarkGray
    }
}

# ── Launch Claude Code ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Starting Claude Code..." -ForegroundColor Green
claude @args
