<#
Install PipHub on Windows with proxy-friendly defaults.

Usage examples:
  # Install for current user (no admin), default dir under %LOCALAPPDATA%
  iwr -useb https://raw.githubusercontent.com/ltanedo/piphub/main/install.ps1 | iex

  # Install to a custom directory
  iwr -useb https://raw.githubusercontent.com/ltanedo/piphub/main/install.ps1 | iex -Args @{ InstallDir = "C:\\tools\\piphub" }

  # System-wide install (requires admin)
  iwr -useb https://raw.githubusercontent.com/ltanedo/piphub/main/install.ps1 | iex -Args @{ System = $true }

  # If behind Zscaler/proxy, inherit your Windows auth for the proxy
  iwr -useb https://raw.githubusercontent.com/ltanedo/piphub/main/install.ps1 | iex -Args @{ ProxyUseDefaultCredentials = $true }

  # From a cloned repo/workspace without any downloads (copies local piphub.ps1)
  .\install.ps1 -FromWorkspace
#>
param(
  [string]$InstallDir,
  [switch]$System,
  [string]$Proxy,
  [switch]$ProxyUseDefaultCredentials,
  [switch]$UseBits,
  [switch]$FromWorkspace
)

$ErrorActionPreference = 'Stop'

function Info([string]$m) { Write-Host "[INFO] $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Warning $m }
function Abort([string]$m) { Write-Error $m; exit 1 }

# Choose install directory
if (-not $InstallDir) {
  if ($System) { $InstallDir = "C:\\Program Files\\piphub" }
  else { $InstallDir = Join-Path $env:LOCALAPPDATA 'piphub' }
}
$BinDir = Join-Path $InstallDir 'bin'

# Check admin if System-wide
if ($System) {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { Abort "System-wide install requires an elevated PowerShell (Run as administrator)." }
}

# Ensure TLS 1.2 for older PowerShell
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# Configure system proxy if requested
if ($ProxyUseDefaultCredentials) {
  try {
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    Info "Using default Windows credentials for proxy"
  } catch { Warn "Failed to set default proxy credentials: $_" }
}

function Ensure-Dir($p) {
  if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Add-ToPath($dir, [ValidateSet('User','Machine')]$scope = 'User') {
  $current = [Environment]::GetEnvironmentVariable('PATH', $scope)
  if (-not $current) { $current = '' }
  $parts = $current.Split(';') | Where-Object { $_ -ne '' }
  if ($parts -notcontains $dir) {
    $new = ($parts + $dir) -join ';'
    [Environment]::SetEnvironmentVariable('PATH', $new, $scope)
    Info "Added to $scope PATH: $dir"
  } else { Info "$dir already on $scope PATH" }
}

function Download-File($url, $outPath) {
  $iwrParams = @{ Uri = $url; OutFile = $outPath; UseBasicParsing = $true }
  if ($Proxy) { $iwrParams.Proxy = $Proxy }
  if ($ProxyUseDefaultCredentials) { $iwrParams.ProxyUseDefaultCredentials = $true }
  try {
    Invoke-WebRequest @iwrParams
    return $true
  } catch {
    Warn "Invoke-WebRequest failed: $($_.Exception.Message)"
    if ($UseBits) {
      try {
        $bitsParams = @{ Source = $url; Destination = $outPath }
        Start-BitsTransfer @bitsParams
        return $true
      } catch {
        Warn "BITS transfer failed: $($_.Exception.Message)"
      }
    }
    return $false
  }
}

# Perform install
Ensure-Dir $BinDir

$piphubPs = Join-Path $BinDir 'piphub-ps.ps1'
$piphubCmd = Join-Path $BinDir 'piphub.cmd'
$piphubBat = Join-Path $BinDir 'piphub.bat'

if ($FromWorkspace -and (Test-Path (Join-Path (Get-Location) 'piphub.ps1'))) {
  Info "Copying local piphub.ps1 from workspace"
  Copy-Item -Force (Join-Path (Get-Location) 'piphub.ps1') $piphubPs
} else {
  $rawUrl = 'https://raw.githubusercontent.com/ltanedo/piphub/main/piphub.ps1'
  Info "Downloading script from: $rawUrl"
  $ok = Download-File -url $rawUrl -outPath $piphubPs
  if (-not $ok) {
    Abort "Failed to download piphub.ps1. If on Zscaler/proxy, re-run with -ProxyUseDefaultCredentials or -UseBits, or run: .\\install.ps1 -FromWorkspace from a cloned repo."
  }
}

# Create lightweight launchers
@"
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0piphub-ps.ps1" %*
"@ | Set-Content -Encoding ascii -Path $piphubCmd

@"
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0piphub-ps.ps1" %*
"@ | Set-Content -Encoding ascii -Path $piphubBat

# Add to PATH
if ($System) { Add-ToPath -dir $BinDir -scope Machine }
else { Add-ToPath -dir $BinDir -scope User }

Info "PipHub installed to: $InstallDir"
Info "Open a new PowerShell and run: piphub"

# Print proxy help if we detected Zscaler-like HTML instead of script
try {
  $firstLine = Get-Content -Path $piphubPs -TotalCount 1 -ErrorAction Stop
  if ($firstLine -notmatch '# piphub.ps1') {
    Warn "Downloaded file did not look like the expected script. Proxy may have intercepted."
    Warn "Try: .\\install.ps1 -ProxyUseDefaultCredentials or .\\install.ps1 -UseBits"
  }
} catch { }

