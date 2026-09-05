<#
.SYNOPSIS
    High-Speed File Upload Script for Windows (PowerShell)
    Supports: GitHub Release, DevUploads, PixelDrain, Temp.sh, GoFile, Oshi.at, SourceForge, VexFiles

.DESCRIPTION
    A powerful, high-performance file upload script for Windows supporting multiple
    file-hosting services with optimizations for SourceForge (FRS) and GoFile.io.
    Supports both interactive menu mode and command-line execution.

.EXAMPLE
    .\upload.ps1
    Interactive mode

.EXAMPLE
    .\upload.ps1 -f "build.zip" -s "gofile"

.EXAMPLE
    .\upload.ps1 -f "rom.zip" -s "sourceforge" -u "john" -p "myproject/v1.0"

.EXAMPLE
    .\upload.ps1 -a -s "sourceforge" -u "john" -p "myproject/peridot"
#>

[CmdletBinding()]
param(
    [Alias("f")]
    [string]$File,

    [Alias("s")]
    [string]$Service,

    [Alias("u")]
    [string]$User,

    [Alias("p")]
    [string]$Path,

    [Alias("r")]
    [string]$Repo,

    [Alias("k")]
    [string]$Key,

    [string]$Folder,

    [Alias("a")]
    [switch]$Auto,

    [Alias("v")]
    [switch]$VerboseMode,

    [Alias("h", "?")]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"

# Script Variables
$script:FilePath   = $File
$script:Service    = $Service
$script:User       = $User
$script:Path       = $Path
$script:Repo       = $Repo
$script:Key        = $Key
$script:FolderId   = $Folder
$script:AutoDetect = $Auto.IsPresent
$script:IsVerbose  = $VerboseMode.IsPresent
$script:ShowHelp   = $Help.IsPresent

# Parse double-dash or remaining POSIX-style flags from $ExtraArgs
if ($ExtraArgs) {
    $i = 0
    while ($i -lt $ExtraArgs.Count) {
        $arg = $ExtraArgs[$i]
        switch -Regex ($arg) {
            '^(--file|-f)$' {
                $i++; if ($i -lt $ExtraArgs.Count) { $script:FilePath = $ExtraArgs[$i] }; break
            }
            '^(--service|-s)$' {
                $i++; if ($i -lt $ExtraArgs.Count) { $script:Service = $ExtraArgs[$i] }; break
            }
            '^(--user|-u)$' {
                $i++; if ($i -lt $ExtraArgs.Count) { $script:User = $ExtraArgs[$i] }; break
            }
            '^(--path|-p)$' {
                $i++; if ($i -lt $ExtraArgs.Count) { $script:Path = $ExtraArgs[$i] }; break
            }
            '^(--repo|-r)$' {
                $i++; if ($i -lt $ExtraArgs.Count) { $script:Repo = $ExtraArgs[$i] }; break
            }
            '^(--key|-k)$' {
                $i++; if ($i -lt $ExtraArgs.Count) { $script:Key = $ExtraArgs[$i] }; break
            }
            '^(--folder)$' {
                $i++; if ($i -lt $ExtraArgs.Count) { $script:FolderId = $ExtraArgs[$i] }; break
            }
            '^(--auto|-a)$' {
                $script:AutoDetect = $true; break
            }
            '^(--verbose|-v)$' {
                $script:IsVerbose = $true; break
            }
            '^(--help|-h|-\?)$' {
                $script:ShowHelp = $true; break
            }
            default {
                Write-Host "Unknown option: $arg" -ForegroundColor Red
                Show-HelpMenu
                exit 1
            }
        }
        $i++
    }
}

function Show-Banner {
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "          🚀 High-Speed File Uploader             " -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-HelpMenu {
    Show-Banner
    Write-Host "USAGE:" -ForegroundColor White
    Write-Host "  Interactive mode:"
    Write-Host "    .\upload.ps1"
    Write-Host "    (or upload.bat)"
    Write-Host ""
    Write-Host "  Command line mode:"
    Write-Host "    .\upload.ps1 -f <file_path> -s <service> [options]"
    Write-Host "    upload.bat -f <file_path> -s <service> [options]"
    Write-Host ""
    Write-Host "SERVICES (-s / --service):" -ForegroundColor White
    Write-Host "  1 | github       GitHub Release"
    Write-Host "  2 | devuploads   DevUploads"
    Write-Host "  3 | pixeldrain   PixelDrain"
    Write-Host "  4 | temp         Temp.sh"
    Write-Host "  5 | gofile       GoFile.io"
    Write-Host "  6 | oshi         Oshi.at"
    Write-Host "  7 | sourceforge  SourceForge (FRS High Speed)"
    Write-Host "  8 | vexfile      VexFiles"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor White
    Write-Host "  -f, --file <path>        Path to the file to upload"
    Write-Host "  -a, --auto               Auto-detect Android ROM zip in out/target/product/*/"
    Write-Host "  -s, --service <service>  Target upload service (number or name)"
    Write-Host "  -u, --user <username>    Username (for SourceForge)"
    Write-Host "  -p, --path <path>        Target path / project folder (for SourceForge)"
    Write-Host "  -r, --repo <owner/repo>  GitHub repository"
    Write-Host "  -k, --key <api_key>      API Key / Token (DevUploads, PixelDrain, GoFile, VexFiles)"
    Write-Host "      --folder <folder_id> Folder ID (for GoFile account upload)"
    Write-Host "  -v, --verbose            Enable verbose output"
    Write-Host "  -h, --help               Show this help menu"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor White
    Write-Host "  .\upload.ps1 -a -s sourceforge -u john -p myproject/peridot"
    Write-Host "  .\upload.ps1 -f build.zip -s gofile"
    Write-Host "  .\upload.ps1 -f rom.zip -s sourceforge -u john -p myproject/v1.0"
    Write-Host "  .\upload.ps1 -f app.apk -s pixeldrain -k YOUR_API_KEY"
    Write-Host "  upload.bat -f build.zip -s gofile"
    Write-Host ""
}

function Get-FormattedSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) {
        return ("{0:N1}G" -f ($Bytes / 1GB))
    } elseif ($Bytes -ge 1MB) {
        return ("{0:N1}M" -f ($Bytes / 1MB))
    } elseif ($Bytes -ge 1KB) {
        return ("{0:N1}K" -f ($Bytes / 1KB))
    } else {
        return ("{0}B" -f $Bytes)
    }
}

function Read-Secret {
    param([string]$PromptMsg)
    $val = ""
    try {
        if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
            $secure = Read-Host -Prompt $PromptMsg -AsSecureString
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
            $val = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        } else {
            $val = Read-Host -Prompt $PromptMsg
        }
    } catch {
        $val = Read-Host -Prompt $PromptMsg
    }
    return $val
}

function Get-CurlCommand {
    $cmd = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        return "curl.exe"
    }
    if (Test-Path "C:\Windows\System32\curl.exe") {
        return "C:\Windows\System32\curl.exe"
    }
    Write-Host "Error: 'curl.exe' is not installed or not in PATH." -ForegroundColor Red
    Write-Host "curl is included with Windows 10 (build 17063+) and Windows 11." -ForegroundColor Yellow
    exit 1
}

function Detect-RomFile {
    $searchDir = "out\target\product"
    if (-not (Test-Path -LiteralPath $searchDir -PathType Container)) {
        $searchDir = "out/target/product"
        if (-not (Test-Path -LiteralPath $searchDir -PathType Container)) {
            return $false
        }
    }

    $zipFiles = @(Get-ChildItem -LiteralPath $searchDir -Filter "*.zip" -Recurse -File -ErrorAction SilentlyContinue)
    if ($zipFiles.Count -eq 0) {
        return $false
    }

    # Filter for zip files >= 1GB (1073741824 bytes), typical for Android ROMs
    $romCandidates = @($zipFiles | Where-Object { $_.Length -ge 1073741824 })
    if ($romCandidates.Count -eq 0) {
        $romCandidates = $zipFiles
    }

    # Sort candidates by modification time (newest first)
    $sortedRoms = @($romCandidates | Sort-Object -Property LastWriteTime -Descending)
    if ($sortedRoms.Count -eq 0) {
        return $false
    }

    if ($sortedRoms.Count -eq 1) {
        $script:FilePath = $sortedRoms[0].FullName
        $sizeStr = Get-FormattedSize -Bytes $sortedRoms[0].Length
        Write-Host "🔍 Auto-detected ROM file: " -NoNewline -ForegroundColor Green
        Write-Host "$script:FilePath " -NoNewline -ForegroundColor White
        Write-Host "($sizeStr)" -ForegroundColor DarkGray
        return $true
    }

    Write-Host "🔍 Found $($sortedRoms.Count) ROM file(s) in ${searchDir}:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $sortedRoms.Count; $i++) {
        $idx = $i + 1
        $r = $sortedRoms[$i]
        $sizeStr = Get-FormattedSize -Bytes $r.Length
        Write-Host "  [$idx] $($r.FullName) ($sizeStr)"
    }

    $choice = Read-Host "Select ROM file [1]"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = "1"
    }
    $choiceNum = 1
    if ([int]::TryParse($choice, [ref]$choiceNum) -and $choiceNum -ge 1 -and $choiceNum -le $sortedRoms.Count) {
        $script:FilePath = $sortedRoms[$choiceNum - 1].FullName
    } else {
        $script:FilePath = $sortedRoms[0].FullName
    }

    Write-Host "Selected ROM: " -NoNewline -ForegroundColor Green
    Write-Host "$script:FilePath" -ForegroundColor White
    return $true
}

function Check-File {
    if ([string]::IsNullOrWhiteSpace($script:FilePath)) {
        Write-Host "Error: No file path specified." -ForegroundColor Red
        exit 1
    }

    $script:FilePath = $script:FilePath.Trim('"', "'", " ")

    if (-not (Test-Path -LiteralPath $script:FilePath -PathType Leaf)) {
        Write-Host "Error: File '$script:FilePath' does not exist or is not a regular file." -ForegroundColor Red
        exit 1
    }

    $script:FilePath = (Resolve-Path -LiteralPath $script:FilePath).Path
}

# ------------------------------------------------------------------------------
# 1. GitHub Release
# ------------------------------------------------------------------------------
function Upload-GitHub {
    $gh = Get-Command "gh.exe" -ErrorAction SilentlyContinue
    if (-not $gh) {
        $gh = Get-Command "gh" -ErrorAction SilentlyContinue
    }
    if (-not $gh) {
        Write-Host "Error: GitHub CLI ('gh') is not installed." -ForegroundColor Red
        Write-Host "Install it with winget: winget install --id GitHub.cli" -ForegroundColor Yellow
        Write-Host "Or download from: https://cli.github.com/" -ForegroundColor Yellow
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($script:Repo)) {
        $script:Repo = Read-Host "Please enter GitHub repo (e.g. owner/repo)"
    }

    if ([string]::IsNullOrWhiteSpace($script:Repo)) {
        Write-Host "Error: GitHub repository is required." -ForegroundColor Red
        exit 1
    }

    $fileName = [System.IO.Path]::GetFileName($script:FilePath)
    $fileNameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($script:FilePath)
    $timestamp = (Get-Date).ToString("yyyyMMddHHmmss")
    $tagName = "${fileNameNoExt}_${timestamp}"

    Write-Host "Started uploading to GitHub Release..." -ForegroundColor Cyan
    Write-Host "Repo: " -NoNewline -ForegroundColor Yellow
    Write-Host "$script:Repo"
    Write-Host "Tag:  " -NoNewline -ForegroundColor Yellow
    Write-Host "$tagName"

    & $gh.Source release create "$tagName" --generate-notes --repo "$script:Repo" 2>$null
    & $gh.Source release upload "$tagName" "$script:FilePath" --clobber --repo "$script:Repo"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✔ GitHub Release upload finished!" -ForegroundColor Green
        Write-Host "URL: https://github.com/$script:Repo/releases/tag/$tagName" -ForegroundColor Green
    } else {
        Write-Host "Error: GitHub Release upload failed with exit code $LASTEXITCODE." -ForegroundColor Red
        exit 1
    }
}

# ------------------------------------------------------------------------------
# 2. DevUploads
# ------------------------------------------------------------------------------
function Upload-DevUploads {
    $curl = Get-CurlCommand

    if ([string]::IsNullOrWhiteSpace($script:Key)) {
        $script:Key = Read-Secret "Please enter DevUploads API key: "
    }

    if ([string]::IsNullOrWhiteSpace($script:Key)) {
        Write-Host "Error: DevUploads API Key is required." -ForegroundColor Red
        exit 1
    }

    Write-Host "Connecting to DevUploads API..." -ForegroundColor Cyan
    $serverResp = & $curl -s "https://devuploads.com/api/upload/server?key=$($script:Key)"
    $json = $null
    try {
        $json = $serverResp | ConvertFrom-Json -ErrorAction SilentlyContinue
    } catch {}

    if (-not $json -or $json.status -ne 200) {
        $msg = if ($json -and $json.msg) { $json.msg } else { "Invalid API key" }
        Write-Host "Error: DevUploads API Key is not valid ($msg)." -ForegroundColor Red
        exit 1
    }

    $sessId = $json.sess_id
    $serverUrl = $json.result

    Write-Host "Started uploading file to DevUploads..." -ForegroundColor Cyan
    $tempRes = [System.IO.Path]::GetTempFileName()
    try {
        & $curl -# -X POST -o "$tempRes" -F "sess_id=$sessId" -F "utype=reg" -F "file=@$($script:FilePath)" "$serverUrl"
        $rawRes = Get-Content -LiteralPath "$tempRes" -Raw -ErrorAction SilentlyContinue

        $fileCode = ""
        try {
            $upJson = $rawRes | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($upJson -and $upJson.file_code) {
                $fileCode = $upJson.file_code
            }
        } catch {}

        if (-not $fileCode -and $rawRes -match '"file_code"\s*:\s*"([^"]+)"') {
            $fileCode = $matches[1]
        }

        if ($fileCode) {
            Write-Host "✔ Upload successful!" -ForegroundColor Green
            Write-Host "Download URL: " -NoNewline -ForegroundColor Green
            Write-Host "https://devuploads.com/$fileCode" -ForegroundColor White
        } else {
            Write-Host "Response: $rawRes"
        }
    } finally {
        if (Test-Path -LiteralPath "$tempRes") {
            Remove-Item -LiteralPath "$tempRes" -Force -ErrorAction SilentlyContinue
        }
    }
}

# ------------------------------------------------------------------------------
# 3. PixelDrain
# ------------------------------------------------------------------------------
function Upload-PixelDrain {
    $curl = Get-CurlCommand

    if ([string]::IsNullOrWhiteSpace($script:Key)) {
        $script:Key = Read-Secret "Please enter PixelDrain API key (press Enter for anonymous): "
    }

    Write-Host "Started uploading file to PixelDrain..." -ForegroundColor Cyan
    $auth = ":$script:Key"
    $response = & $curl -# -T "$script:FilePath" -u "$auth" https://pixeldrain.com/api/file/

    $fileId = ""
    try {
        $json = $response | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($json -and $json.id) {
            $fileId = $json.id
        }
    } catch {}

    if (-not $fileId -and $response -match '"id"\s*:\s*"([^"]+)"') {
        $fileId = $matches[1]
    }

    if ($fileId) {
        Write-Host "✔ Upload successful!" -ForegroundColor Green
        Write-Host "Download URL: " -NoNewline -ForegroundColor Green
        Write-Host "https://pixeldrain.com/u/$fileId" -ForegroundColor White
    } else {
        Write-Host "Upload response: $response" -ForegroundColor Red
    }
}

# ------------------------------------------------------------------------------
# 4. Temp.sh
# ------------------------------------------------------------------------------
function Upload-TempSh {
    $curl = Get-CurlCommand

    Write-Host "Started uploading file to Temp.sh..." -ForegroundColor Cyan
    $response = & $curl -# -F "file=@$($script:FilePath)" https://temp.sh/upload

    Write-Host "✔ Upload completed!" -ForegroundColor Green
    Write-Host "Download URL: " -NoNewline -ForegroundColor Green
    Write-Host "$response" -ForegroundColor White
}

# ------------------------------------------------------------------------------
# 5. GoFile
# ------------------------------------------------------------------------------
function Upload-GoFile {
    $curl = Get-CurlCommand

    $token = $script:Key
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Host "Creating GoFile guest session..." -ForegroundColor Cyan
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            $accountResp = & $curl -s -A "Mozilla/5.0" --connect-timeout 10 -X POST https://api.gofile.io/accounts
            try {
                $accJson = $accountResp | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($accJson -and $accJson.data -and $accJson.data.token) {
                    $token = $accJson.data.token
                    break
                }
            } catch {}
            Start-Sleep -Seconds 1
        }
    }

    Write-Host "Fetching best available GoFile server..." -ForegroundColor Cyan
    $server = ""
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $serverResp = & $curl -s --connect-timeout 10 -A "Mozilla/5.0" https://api.gofile.io/servers
        try {
            $srvJson = $serverResp | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($srvJson -and $srvJson.data) {
                if ($srvJson.data.servers -and $srvJson.data.servers.Count -gt 0 -and $srvJson.data.servers[0].name) {
                    $server = $srvJson.data.servers[0].name
                    break
                } elseif ($srvJson.data.serversAllZone -and $srvJson.data.serversAllZone.Count -gt 0 -and $srvJson.data.serversAllZone[0].name) {
                    $server = $srvJson.data.serversAllZone[0].name
                    break
                }
            }
        } catch {}
        Start-Sleep -Seconds 1
    }

    if ([string]::IsNullOrWhiteSpace($server)) {
        Write-Host "Warning: Could not fetch server dynamically, falling back to 'store3'." -ForegroundColor Yellow
        $server = "store3"
    }

    Write-Host "Uploading to GoFile server [" -NoNewline -ForegroundColor Cyan
    Write-Host "$server" -NoNewline -ForegroundColor White
    Write-Host "]..." -ForegroundColor Cyan

    $curlArgs = @("-#", "-A", "Mozilla/5.0", "-F", "file=@$($script:FilePath)")
    if (-not [string]::IsNullOrWhiteSpace($token)) {
        $curlArgs += @("-F", "token=$token")
    }
    if (-not [string]::IsNullOrWhiteSpace($script:FolderId)) {
        $curlArgs += @("-F", "folderId=$script:FolderId")
    }
    $curlArgs += "https://$server.gofile.io/contents/uploadfile"

    $response = & $curl @curlArgs
    $downloadUrl = ""
    try {
        $json = $response | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($json -and $json.data -and $json.data.downloadPage) {
            $downloadUrl = $json.data.downloadPage
        }
    } catch {}

    if (-not $downloadUrl -and $response -match '"downloadPage"\s*:\s*"([^"]+)"') {
        $downloadUrl = $matches[1]
    }

    if ($downloadUrl) {
        Write-Host "✔ GoFile upload successful!" -ForegroundColor Green
        Write-Host "Download Page: " -NoNewline -ForegroundColor Green
        Write-Host "$downloadUrl" -ForegroundColor White
    } else {
        Write-Host "Upload failed or invalid response from GoFile:" -ForegroundColor Red
        Write-Host "$response"
        exit 1
    }
}

# ------------------------------------------------------------------------------
# 6. Oshi.at
# ------------------------------------------------------------------------------
function Upload-Oshi {
    $curl = Get-CurlCommand

    Write-Host "Started uploading file to Oshi.at..." -ForegroundColor Cyan
    $response = & $curl -# -F "file=@$($script:FilePath)" https://oshi.at

    Write-Host "✔ Upload completed!" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Green
    Write-Host "$response"
}

# ------------------------------------------------------------------------------
# 7. SourceForge (FRS High Speed Optimization)
# ------------------------------------------------------------------------------
function Upload-SourceForge {
    if ([string]::IsNullOrWhiteSpace($script:User)) {
        $script:User = Read-Host "Please enter SourceForge Username"
    }

    if ([string]::IsNullOrWhiteSpace($script:Path)) {
        $detectedCodename = ""
        if ($script:FilePath -match 'out[\\/]target[\\/]product[\\/]([^\\/]+)') {
            $detectedCodename = $matches[1]
        }

        Write-Host "Please enter upload location on SourceForge:"
        if ($detectedCodename) {
            Write-Host "Detected device codename: " -NoNewline -ForegroundColor Yellow
            Write-Host "$detectedCodename" -ForegroundColor White
            Write-Host "Note: Format as 'project_name/folder' (e.g. myproject/$detectedCodename)" -ForegroundColor Yellow
        } else {
            Write-Host "Note: Format as 'project_name/folder' (e.g. myproject/v1.0)" -ForegroundColor Yellow
        }
        $script:Path = Read-Host "Path"
    }

    if ([string]::IsNullOrWhiteSpace($script:Key)) {
        $script:Key = Read-Secret "Please enter SourceForge Password (press Enter to use SSH Key / terminal prompt)"
    }

    # Sanitize remote path to avoid duplicate /home/frs/project/ prefixes
    $cleanPath = $script:Path.Replace('\', '/')
    if ($cleanPath.StartsWith("/home/frs/project/")) {
        $cleanPath = $cleanPath.Substring(18)
    }
    $cleanPath = $cleanPath.TrimStart('/')

    if ([string]::IsNullOrWhiteSpace($script:User) -or [string]::IsNullOrWhiteSpace($cleanPath)) {
        Write-Host "Error: Username and target path are required for SourceForge." -ForegroundColor Red
        exit 1
    }

    $targetHost = "frs.sourceforge.net"
    $fullRemoteDest = "/home/frs/project/$cleanPath"
    $projectName = $cleanPath.Split('/')[0]
    $subPath = if ($cleanPath.Contains('/')) { $cleanPath.Substring($projectName.Length + 1) } else { "" }

    $fileInfo = Get-Item -LiteralPath $script:FilePath
    $fileName = $fileInfo.Name
    $fileSizeStr = Get-FormattedSize -Bytes $fileInfo.Length

    Write-Host "Preparing SourceForge high-speed upload..." -ForegroundColor Cyan
    Write-Host "File:   " -NoNewline -ForegroundColor Yellow
    Write-Host "$fileName ($fileSizeStr)"
    Write-Host "Target: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($script:User)@${targetHost}:${fullRemoteDest}/"

    # High performance SSH options:
    # - IPQoS=throughput: Optimizes TCP buffer windowing for maximum network throughput
    # - Compression=no: Avoids wasting CPU re-compressing zip/iso/rom archives
    # - Optimized Ciphers: Prioritizes fast modern ciphers (ChaCha20-Poly1305, AES-GCM)
    $sshOpts = @(
        "-o", "IPQoS=throughput",
        "-o", "Compression=no",
        "-o", "ServerAliveInterval=15",
        "-o", "ServerAliveCountMax=6",
        "-o", "Ciphers=chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com"
    )

    $rsyncCmd = Get-Command "rsync.exe" -ErrorAction SilentlyContinue
    if (-not $rsyncCmd) {
        $rsyncCmd = Get-Command "rsync" -ErrorAction SilentlyContinue
    }

    $sshpassCmd = Get-Command "sshpass.exe" -ErrorAction SilentlyContinue
    if (-not $sshpassCmd) {
        $sshpassCmd = Get-Command "sshpass" -ErrorAction SilentlyContinue
    }

    if (-not [string]::IsNullOrWhiteSpace($script:Key) -and -not $sshpassCmd) {
        Write-Host "Note: 'sshpass' not installed. SSH will prompt for password interactively if SSH key is not set up." -ForegroundColor Yellow
    }

    if ($rsyncCmd) {
        Write-Host "🚀 Utilizing optimized rsync protocol (Maximum speed + resumable)..." -ForegroundColor Green
        $sshOptString = "ssh " + ($sshOpts -join " ")
        $rsyncArgs = @(
            "-avP",
            "--info=progress2",
            "--partial",
            "--rsync-path=mkdir -p ${fullRemoteDest} && rsync",
            "-e", $sshOptString,
            $script:FilePath,
            "$($script:User)@${targetHost}:${fullRemoteDest}/"
        )

        if (-not [string]::IsNullOrWhiteSpace($script:Key) -and $sshpassCmd) {
            $env:SSHPASS = $script:Key
            & $sshpassCmd -e $rsyncCmd.Source @rsyncArgs
        } else {
            & $rsyncCmd.Source @rsyncArgs
        }
    } else {
        Write-Host "rsync not detected. Falling back to optimized scp..." -ForegroundColor Yellow

        $scpCmd = Get-Command "scp.exe" -ErrorAction SilentlyContinue
        if (-not $scpCmd) {
            $scpCmd = Get-Command "scp" -ErrorAction SilentlyContinue
        }
        if (-not $scpCmd) {
            if (Test-Path "C:\Windows\System32\OpenSSH\scp.exe") {
                $scpCmd = "C:\Windows\System32\OpenSSH\scp.exe"
            } else {
                Write-Host "Error: Neither rsync nor scp was found." -ForegroundColor Red
                exit 1
            }
        }

        $scpArgs = @()
        $scpArgs += $sshOpts
        $scpArgs += $script:FilePath
        $scpArgs += "$($script:User)@${targetHost}:${fullRemoteDest}/"

        $scpTarget = if ($scpCmd -is [string]) { $scpCmd } else { $scpCmd.Source }

        if (-not [string]::IsNullOrWhiteSpace($script:Key) -and $sshpassCmd) {
            $env:SSHPASS = $script:Key
            & $sshpassCmd -e $scpTarget @scpArgs
        } else {
            & $scpTarget @scpArgs
        }
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✔ Upload to SourceForge completed!" -ForegroundColor Green
        $filesUrl = "https://sourceforge.net/projects/$projectName/files/$subPath"
        if (-not $filesUrl.EndsWith('/')) { $filesUrl += "/" }
        Write-Host "Files URL: " -NoNewline -ForegroundColor Green
        Write-Host "$filesUrl" -ForegroundColor White
    } else {
        Write-Host "Upload to SourceForge exited with code $LASTEXITCODE." -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------------------
# 8. VexFiles
# ------------------------------------------------------------------------------
function Upload-VexFile {
    $curl = Get-CurlCommand

    if ([string]::IsNullOrWhiteSpace($script:Key)) {
        $script:Key = Read-Secret "Please enter VexFiles API Key: "
    }

    if ([string]::IsNullOrWhiteSpace($script:Key)) {
        Write-Host "Error: VexFiles API token is required." -ForegroundColor Red
        exit 1
    }

    Write-Host "Started uploading file to VexFiles..." -ForegroundColor Cyan
    $response = & $curl -# -X POST https://vexfile.com/api/upload/handle `
        -H "Content-Type: multipart/form-data" `
        -F "token=$script:Key" `
        -F "file=@$($script:FilePath)"

    Write-Host "✔ Upload completed!" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Green
    Write-Host "$response"
}

# ------------------------------------------------------------------------------
# Main Execution Logic
# ------------------------------------------------------------------------------

if ($script:ShowHelp) {
    Show-HelpMenu
    exit 0
}

# Auto-detect ROM file if requested or if FilePath is empty
if ([string]::IsNullOrWhiteSpace($script:FilePath) -or $script:AutoDetect) {
    $null = Detect-RomFile
}

# Interactive Mode if service or file not provided
if ([string]::IsNullOrWhiteSpace($script:Service) -or [string]::IsNullOrWhiteSpace($script:FilePath)) {
    Show-Banner
    Write-Host "Select Upload Host:" -ForegroundColor White
    Write-Host "  [1] GitHub Release       " -NoNewline; Write-Host "[gh auth login]" -ForegroundColor Magenta
    Write-Host "  [2] DevUploads          " -NoNewline; Write-Host "[API Key]" -ForegroundColor Magenta
    Write-Host "  [3] PixelDrain          " -NoNewline; Write-Host "[API Key]" -ForegroundColor Magenta
    Write-Host "  [4] Temp.sh             " -NoNewline; Write-Host "[Anonymous]" -ForegroundColor Magenta
    Write-Host "  [5] GoFile              " -NoNewline; Write-Host "[Fast Auto Server]" -ForegroundColor Magenta
    Write-Host "  [6] Oshi.at             " -NoNewline; Write-Host "[Anonymous]" -ForegroundColor Magenta
    Write-Host "  [7] SourceForge (FRS)   " -NoNewline; Write-Host "[High-Speed rsync/scp]" -ForegroundColor Green
    Write-Host "  [8] VexFiles            " -NoNewline; Write-Host "[API Key]" -ForegroundColor Magenta
    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($script:Service)) {
        $script:Service = Read-Host "Enter number [1-8]"
    }

    if ([string]::IsNullOrWhiteSpace($script:FilePath)) {
        $script:FilePath = Read-Host "Please enter file path"
    }
}

Check-File

# Normalize Service selection
switch -Regex ($script:Service.ToLower().Trim()) {
    '^(1|github)$' {
        Upload-GitHub
        break
    }
    '^(2|devuploads)$' {
        Upload-DevUploads
        break
    }
    '^(3|pixeldrain)$' {
        Upload-PixelDrain
        break
    }
    '^(4|temp|temp\.sh)$' {
        Upload-TempSh
        break
    }
    '^(5|gofile)$' {
        Upload-GoFile
        break
    }
    '^(6|oshi|oshi\.at)$' {
        Upload-Oshi
        break
    }
    '^(7|sourceforge|sf)$' {
        Upload-SourceForge
        break
    }
    '^(8|vexfile|vexfiles)$' {
        Upload-VexFile
        break
    }
    default {
        Write-Host "Error: Invalid service selected: '$script:Service'" -ForegroundColor Red
        exit 1
    }
}
