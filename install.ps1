# GTA-VI-caliber - one-command installer & launcher (Windows / PowerShell).
#
#   iwr https://raw.githubusercontent.com/duolahypercho/gta-vi-caliber/main/install.ps1 | iex
#
# Downloads the Godot 4.6 engine and git-lfs locally (no admin), clones the
# game with its art assets, and launches straight into play. Re-running
# updates an existing copy instead of re-cloning.

$ErrorActionPreference = 'Stop'

$RepoUrl       = if ($env:GTA6_REPO)            { $env:GTA6_REPO }            else { 'https://github.com/duolahypercho/gta-vi-caliber.git' }
$RepoBranch    = if ($env:GTA6_BRANCH)          { $env:GTA6_BRANCH }          else { 'main' }
$GodotVersion  = if ($env:GTA6_GODOT_VERSION)   { $env:GTA6_GODOT_VERSION }   else { '4.6' }
$GitLfsVersion = if ($env:GTA6_GIT_LFS_VERSION) { $env:GTA6_GIT_LFS_VERSION } else { '3.5.1' }
$InstallDir    = if ($env:GTA6_HOME)            { $env:GTA6_HOME }            else { Join-Path $HOME 'gta-vi-caliber' }
$CacheDir      = if ($env:GTA6_CACHE)           { $env:GTA6_CACHE }           else { Join-Path $env:LOCALAPPDATA 'gta-vi-caliber' }

function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Die($m)  { Write-Host "error: $m" -ForegroundColor Red; exit 1 }

Write-Host 'GTA-VI-caliber installer' -ForegroundColor White
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Die "git is missing. Install it from https://git-scm.com/download/win then re-run this command."
}

function Fetch($url, $out) {
  Info "downloading $(Split-Path $url -Leaf)"
  Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
}

# --- git-lfs (local) --------------------------------------------------------
$lfsOnPath = $false
try { git lfs version *> $null; $lfsOnPath = $true } catch {}
if (-not $lfsOnPath) {
  $lfsDir = Join-Path $CacheDir 'git-lfs'
  $lfsBin = Join-Path $lfsDir 'git-lfs.exe'
  if (-not (Test-Path $lfsBin)) {
    $asset = "git-lfs-windows-amd64-v$GitLfsVersion.zip"
    $zip = Join-Path $CacheDir $asset
    Fetch "https://github.com/git-lfs/git-lfs/releases/download/v$GitLfsVersion/$asset" $zip
    if (Test-Path $lfsDir) { Remove-Item -Recurse -Force $lfsDir }
    Expand-Archive -Path $zip -DestinationPath $lfsDir -Force
    if (-not (Test-Path $lfsBin)) {
      $found = Get-ChildItem -Path $lfsDir -Filter 'git-lfs.exe' -Recurse | Select-Object -First 1
      if ($found) { Copy-Item $found.FullName $lfsBin }
    }
  }
  $env:PATH = "$lfsDir;$env:PATH"
  git lfs install --skip-repo *> $null
  Info 'git-lfs: ready (local)'
} else {
  Info 'git-lfs: present'
}

# --- Godot engine (local) ---------------------------------------------------
$godotDir = Join-Path $CacheDir "godot-$GodotVersion"
$godotBin = Join-Path $godotDir "Godot_v$GodotVersion-stable_win64.exe"
if (-not (Test-Path $godotBin)) {
  Info "Godot: downloading engine $GodotVersion (~120 MB, one time)"
  $asset = "Godot_v$GodotVersion-stable_win64.exe.zip"
  $zip = Join-Path $CacheDir $asset
  try {
    Fetch "https://github.com/godotengine/godot-builds/releases/download/$GodotVersion-stable/$asset" $zip
  } catch {
    Fetch "https://github.com/godotengine/godot/releases/download/$GodotVersion-stable/$asset" $zip
  }
  if (Test-Path $godotDir) { Remove-Item -Recurse -Force $godotDir }
  Expand-Archive -Path $zip -DestinationPath $godotDir -Force
  if (-not (Test-Path $godotBin)) {
    $found = Get-ChildItem -Path $godotDir -Filter '*.exe' -Recurse | Select-Object -First 1
    if ($found) { $godotBin = $found.FullName } else { Die 'Godot extraction failed' }
  }
}
Info "Godot: ready ($GodotVersion)"

# --- clone or update --------------------------------------------------------
if (Test-Path (Join-Path $InstallDir '.git')) {
  Info "Updating existing copy in $InstallDir"
  git -C $InstallDir fetch --depth 1 origin $RepoBranch
  git -C $InstallDir reset --hard "origin/$RepoBranch"
  git -C $InstallDir lfs pull
} else {
  Info "Cloning into $InstallDir (this pulls art assets too)"
  git clone --depth 1 --branch $RepoBranch $RepoUrl $InstallDir
  git -C $InstallDir lfs pull
}

Write-Host ''
Write-Host 'Done. Launching GTA-VI-caliber...' -ForegroundColor White
Info "To play again later, re-run the same command, or:"
Write-Host "       `"$godotBin`" --path `"$(Join-Path $InstallDir 'game')`""
Write-Host ''

& $godotBin --path (Join-Path $InstallDir 'game')
