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

  # Use winget to install Git, clone repo, and install to WindowsApps (proxy-friendly)
  .\install.ps1 -UseWinget
#>
param(
  [string]$InstallDir,
  [switch]$System,
  [string]$Proxy,
  [switch]$ProxyUseDefaultCredentials,
  [switch]$UseBits,
  [switch]$FromWorkspace,
  [switch]$UseWinget
)

$ErrorActionPreference = 'Stop'

function Info([string]$m) { Write-Host "[INFO] $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Warning $m }
function Abort([string]$m) { Write-Error $m; exit 1 }

# Choose install directory
if (-not $InstallDir) {
  if ($UseWinget) { $InstallDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps' }
  elseif ($System) { $InstallDir = "C:\\Program Files\\piphub" }
  else { $InstallDir = Join-Path $env:LOCALAPPDATA 'piphub' }
}

if ($UseWinget) { $BinDir = $InstallDir }
else { $BinDir = Join-Path $InstallDir 'bin' }

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

if ($UseWinget) {
  $piphubPs = Join-Path $BinDir 'piphub-ps.ps1'
  $piphubCmd = Join-Path $BinDir 'piphub.cmd'
  $piphubBat = Join-Path $BinDir 'piphub.bat'
} else {
  $piphubPs = Join-Path $BinDir 'piphub-ps.ps1'
  $piphubCmd = Join-Path $BinDir 'piphub.cmd'
  $piphubBat = Join-Path $BinDir 'piphub.bat'
}

if ($UseWinget) {
  Info "Using winget to install Git and clone repo (proxy-friendly)"

  # Install Git via winget if not available
  try {
    $null = Get-Command git -ErrorAction Stop
    Info "Git already available"
  } catch {
    Info "Installing Git via winget..."
    winget install -e --id Git.Git --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
      Abort "Failed to install Git via winget"
    }
    # Refresh PATH to pick up Git
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
  }

  # Clone repo to temp location
  $tempRepo = Join-Path $env:TEMP "piphub-repo-$(Get-Random)"
  Info "Cloning piphub repo to: $tempRepo"
  git clone https://github.com/ltanedo/piphub.git $tempRepo
  if ($LASTEXITCODE -ne 0) {
    Abort "Failed to clone piphub repository"
  }

  # Copy the script
  $sourceScript = Join-Path $tempRepo 'piphub.ps1'
  if (-not (Test-Path $sourceScript)) {
    Abort "piphub.ps1 not found in cloned repo"
  }
  Copy-Item -Force $sourceScript $piphubPs

  # Cleanup temp repo
  Remove-Item -Recurse -Force $tempRepo -ErrorAction SilentlyContinue

} elseif ($FromWorkspace -and (Test-Path (Join-Path (Get-Location) 'piphub.ps1'))) {
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

# Add to PATH (skip for UseWinget since WindowsApps is already on PATH)
if ($UseWinget) {
  Info "WindowsApps directory is already on PATH"
} elseif ($System) {
  Add-ToPath -dir $BinDir -scope Machine
} else {
  Add-ToPath -dir $BinDir -scope User
}

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

