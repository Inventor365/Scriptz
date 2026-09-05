# 🚀 High-Speed File Upload Script

A powerful, high-performance upload script for **Linux**, **macOS**, and **Windows** supporting multiple file-hosting services with specialized performance optimizations for **SourceForge (FRS)** and **GoFile.io**.

Designed for developers, ROM maintainers, CI/CD pipelines, and terminal enthusiasts.

---

## ✨ Features

- 💻 **Cross-Platform**: Full native support for **Linux / macOS** (`upload.sh`) and **Windows** (`upload.ps1`, `upload.bat`).
- 📱 **Android ROM Auto-Detection**: Automatically detects built ROM `.zip` files (2GB+ / 3GB+) located in `out/target/product/<codename>/` without needing to type long paths.
- ⚡ **High-Speed SourceForge Uploads**: Solves slow transfer speeds on SourceForge by using `rsync` / optimized `scp` over SSH with TCP QoS, disabled compression on archives, and high-performance ciphers (`ChaCha20-Poly1305`, `AES-128-GCM`).
- 🔄 **Resumable Transfers**: Interrupted SourceForge uploads automatically resume where they left off without wasting bandwidth.
- 🎯 **Smart GoFile Integration**: Dynamically queries GoFile APIs to locate the best available server, with optional API Token and Folder ID support.
- 🛠️ **Multi-Service Support**:
  1. **GitHub Release** (via `gh` CLI)
  2. **DevUploads**
  3. **PixelDrain**
  4. **Temp.sh**
  5. **GoFile.io**
  6. **Oshi.at**
  7. **SourceForge (FRS)**
  8. **VexFiles**
- 🖥️ **Dual Mode Execution**:
  - **Interactive Mode**: Easy terminal UI with clear prompts.
  - **CLI / Pipeline Mode**: Fully automatable with command-line flags.

---

## 🚀 Quick Start

### 🪟 Windows

#### Run directly from PowerShell:
```powershell
irm https://raw.githubusercontent.com/Inventor365/Scriptz/main/upload.ps1 | iex
```

#### Local Clone & Run:
```powershell
git clone https://github.com/Inventor365/Scriptz.git
cd Scriptz

# Interactive mode:
.\upload.ps1

# Or double-click upload.bat / run from CMD:
upload.bat
```

#### Windows CLI Examples:
```powershell
# GoFile
.\upload.ps1 -f "build.zip" -s gofile

# SourceForge High-Speed
.\upload.ps1 -f "rom.zip" -s sourceforge -u "username" -p "myproject/v1.0"

# Auto-detect Android ROM
.\upload.ps1 -a -s sourceforge -u "username" -p "myproject/peridot"

# PixelDrain with API key
.\upload.ps1 -f "app.apk" -s pixeldrain -k "YOUR_API_KEY"

# Using Command Prompt (upload.bat)
upload.bat -f "build.zip" -s gofile
```

---

### 🐧 Linux & macOS

#### Run directly from Git / Curl:
```bash
# Interactive mode
bash <(curl -sL https://raw.githubusercontent.com/Inventor365/Scriptz/main/upload.sh)

# CLI mode example (GoFile)
bash <(curl -sL https://raw.githubusercontent.com/Inventor365/Scriptz/main/upload.sh) -f "build.zip" -s gofile

# CLI mode example (SourceForge)
bash <(curl -sL https://raw.githubusercontent.com/Inventor365/Scriptz/main/upload.sh) -f "rom.zip" -s sourceforge -u "username" -p "myproject/v1.0"
```

#### Local Clone & Run:
```bash
git clone https://github.com/Inventor365/Scriptz.git && cd Scriptz && chmod +x upload.sh && ./upload.sh
```

---

## 📖 Command Line Options

```text
USAGE:
  Interactive mode:
    Linux / macOS:  ./upload.sh
    Windows:        .\upload.ps1  (or upload.bat)

  Command line mode:
    Linux / macOS:  ./upload.sh -f <file_path> -s <service> [options]
    Windows:        .\upload.ps1 -f <file_path> -s <service> [options]
                    upload.bat -f <file_path> -s <service> [options]

SERVICES (-s / --service):
  1 | github       GitHub Release
  2 | devuploads   DevUploads
  3 | pixeldrain   PixelDrain
  4 | temp         Temp.sh
  5 | gofile       GoFile.io
  6 | oshi         Oshi.at
  7 | sourceforge  SourceForge (FRS High Speed)
  8 | vexfile      VexFiles

OPTIONS:
  -f, --file <path>        Path to the file to upload
  -a, --auto               Auto-detect Android ROM zip in out/target/product/*/
  -s, --service <service>  Target upload service (number or name)
  -u, --user <username>    Username (for SourceForge)
  -p, --path <path>        Target path / project folder (for SourceForge)
  -r, --repo <owner/repo>  GitHub repository (e.g. owner/repo)
  -k, --key <api_key>      API Key / Token (DevUploads, PixelDrain, GoFile, VexFiles)
      --folder <folder_id> Folder ID (for GoFile account upload)
  -v, --verbose            Enable verbose output
  -h, --help               Show help menu
```

---

## 🏎️ Why is SourceForge Upload so much faster?

Standard `scp` commands suffer from low network throughput over high-latency connections because classic SCP uses synchronous ACK-based blocking packets. Additionally, default SSH settings waste CPU attempting to compress binary data (ZIP/ISO/ROMs).

This script solves this issue by:
1. Using **`rsync` streaming pipeline protocol** instead of legacy SCP blocking buffers.
2. Setting **`IPQoS=throughput`** for TCP window optimization.
3. Disabling **SSH Compression (`Compression=no`)** on pre-compressed file archives.
4. Enabling **modern vector ciphers** (`chacha20-poly1305@openssh.com`, `aes128-gcm@openssh.com`).
5. Enabling **resumable uploads (`--partial`)** and **automatic remote directory creation**.

---

## 📄 License

MIT License. Feel free to fork and adapt!
