#!/usr/bin/env bash
#
# High-Speed File Upload Script
# Supports: GitHub Release, DevUploads, PixelDrain, Temp.sh, GoFile, Oshi.at, SourceForge, VexFiles
#

set -e

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Global Variables
FILE_PATH=""
SERVICE=""
KEY=""
USER_NAME=""
REMOTE_PATH=""
GH_REPO=""
FOLDER_ID=""
VERBOSE=0

show_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "=================================================="
    echo "          🚀 High-Speed File Uploader             "
    echo "=================================================="
    echo -e "${NC}"
}

show_help() {
    show_banner
    echo -e "${BOLD}USAGE:${NC}"
    echo "  Interactive mode:"
    echo "    ./upload.sh"
    echo ""
    echo "  Command line mode:"
    echo "    ./upload.sh -f <file_path> -s <service> [options]"
    echo ""
    echo -e "${BOLD}SERVICES (-s / --service):${NC}"
    echo "  1 | github       GitHub Release"
    echo "  2 | devuploads   DevUploads"
    echo "  3 | pixeldrain   PixelDrain"
    echo "  4 | temp         Temp.sh"
    echo "  5 | gofile       GoFile.io"
    echo "  6 | oshi         Oshi.at"
    echo "  7 | sourceforge  SourceForge (FRS High Speed)"
    echo "  8 | vexfile      VexFiles"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "  -f, --file <path>        Path to the file to upload"
    echo "  -a, --auto               Auto-detect Android ROM zip in out/target/product/*/"
    echo "  -s, --service <service>  Target upload service (number or name)"
    echo "  -u, --user <username>    Username (for SourceForge)"
    echo "  -p, --path <path>        Target path / project folder (for SourceForge)"
    echo "  -r, --repo <owner/repo>  GitHub repository"
    echo "  -k, --key <api_key>      API Key / Token (DevUploads, PixelDrain, GoFile, VexFiles)"
    echo "      --folder <folder_id> Folder ID (for GoFile account upload)"
    echo "  -v, --verbose            Enable verbose output"
    echo "  -h, --help               Show this help menu"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  ./upload.sh -a -s sourceforge -u john -p myproject/peridot"
    echo "  ./upload.sh -f build.zip -s gofile"
    echo "  ./upload.sh -f rom.zip -s sourceforge -u john -p myproject/v1.0"
    echo "  ./upload.sh -f app.apk -s pixeldrain -k YOUR_API_KEY"
    echo ""
}

read_secret() {
    local prompt_msg="$1"
    local secret_val=""
    if [ -t 0 ]; then
        read -rsp "$prompt_msg" secret_val
        echo ""
    else
        read -r secret_val
    fi
    echo "$secret_val"
}

detect_rom_file() {
    local search_dir="out/target/product"
    if [ ! -d "$search_dir" ]; then
        return 1
    fi

    # Search for .zip files in out/target/product/*/*.zip
    local zip_files=()
    while IFS= read -r line; do
        [ -n "$line" ] && zip_files+=("$line")
    done < <(find "$search_dir" -type f -name "*.zip" 2>/dev/null)

    if [ ${#zip_files[@]} -eq 0 ]; then
        return 1
    fi

    # Filter for zip files >= 1GB (1073741824 bytes), typical for Android ROMs
    local rom_candidates=()
    for f in "${zip_files[@]}"; do
        local sz_bytes
        sz_bytes=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo 0)
        if [ "$sz_bytes" -ge 1073741824 ]; then
            rom_candidates+=("$f")
        fi
    done

    # Fallback to all zip files if none >= 1GB
    if [ ${#rom_candidates[@]} -eq 0 ]; then
        rom_candidates=("${zip_files[@]}")
    fi

    # Sort candidates by modification time (newest first)
    local sorted_roms=()
    while IFS= read -r line; do
        [ -n "$line" ] && sorted_roms+=("$line")
    done < <(ls -1t "${rom_candidates[@]}" 2>/dev/null)

    if [ ${#sorted_roms[@]} -eq 0 ]; then
        return 1
    fi

    if [ ${#sorted_roms[@]} -eq 1 ]; then
        FILE_PATH="${sorted_roms[0]}"
        echo -e "${GREEN}🔍 Auto-detected ROM file:${NC} ${BOLD}$FILE_PATH${NC} ($(du -h "$FILE_PATH" | cut -f1))"
        return 0
    fi

    echo -e "${CYAN}🔍 Found ${#sorted_roms[@]} ROM file(s) in $search_dir:${NC}"
    local idx=1
    for r in "${sorted_roms[@]}"; do
        echo -e "  [$idx] $r ($(du -h "$r" | cut -f1))"
        ((idx++))
    done

    if [ -t 0 ]; then
        read -p "Select ROM file [1]: " choice
        choice=${choice:-1}
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#sorted_roms[@]}" ]; then
            FILE_PATH="${sorted_roms[$((choice-1))]}"
        else
            FILE_PATH="${sorted_roms[0]}"
        fi
    else
        FILE_PATH="${sorted_roms[0]}"
    fi
    echo -e "${GREEN}Selected ROM:${NC} ${BOLD}$FILE_PATH${NC}"
    return 0
}

check_file() {
    if [ -z "$FILE_PATH" ]; then
        echo -e "${RED}Error: No file path specified.${NC}"
        exit 1
    fi

    if [ ! -f "$FILE_PATH" ]; then
        echo -e "${RED}Error: File '$FILE_PATH' does not exist or is not a regular file.${NC}"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# 1. GitHub Release
# ------------------------------------------------------------------------------
upload_github() {
    if ! command -v gh &>/dev/null; then
        echo -e "${RED}Error: GitHub CLI ('gh') is not installed.${NC}"
        echo -e "Install it from: https://cli.github.com/"
        exit 1
    fi

    if [ -z "$GH_REPO" ]; then
        read -p "Please enter GitHub repo (e.g. owner/repo): " GH_REPO
    fi

    if [ -z "$GH_REPO" ]; then
        echo -e "${RED}Error: GitHub repository is required.${NC}"
        exit 1
    fi

    local filename
    filename="$(basename "$FILE_PATH")"
    local tag_name
    tag_name="${filename%.*}_$(date +%Y%m%d%H%M%S)"

    echo -e "${CYAN}Started uploading to GitHub Release...${NC}"
    echo -e "${YELLOW}Repo:${NC} $GH_REPO"
    echo -e "${YELLOW}Tag:${NC} $tag_name"

    gh release create "$tag_name" --generate-notes --repo "$GH_REPO" || true
    gh release upload "$tag_name" "$FILE_PATH" --clobber --repo "$GH_REPO"

    echo -e "${GREEN}✔ GitHub Release upload finished!${NC}"
    echo -e "${GREEN}URL:${NC} https://github.com/$GH_REPO/releases/tag/$tag_name"
}

# ------------------------------------------------------------------------------
# 2. DevUploads
# ------------------------------------------------------------------------------
upload_devuploads() {
    if [ -z "$KEY" ]; then
        KEY=$(read_secret "Please enter DevUploads API key: ")
    fi

    if [ -z "$KEY" ]; then
        echo -e "${RED}Error: DevUploads API Key is required.${NC}"
        exit 1
    fi

    echo -e "${CYAN}Started uploading file to DevUploads...${NC}"
    bash <(curl -s https://devuploads.com/upload.sh) -f "$FILE_PATH" -k "$KEY"
}

# ------------------------------------------------------------------------------
# 3. PixelDrain
# ------------------------------------------------------------------------------
upload_pixeldrain() {
    if [ -z "$KEY" ]; then
        KEY=$(read_secret "Please enter PixelDrain API key (press Enter for anonymous): ")
    fi

    echo -e "${CYAN}Started uploading file to PixelDrain...${NC}"
    local response
    response=$(curl -# -T "$FILE_PATH" -u ":$KEY" https://pixeldrain.com/api/file/)

    local file_id=""
    if command -v jq &>/dev/null; then
        file_id=$(echo "$response" | jq -r '.id // empty')
    elif command -v python3 &>/dev/null; then
        file_id=$(echo "$response" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("id",""))' 2>/dev/null)
    else
        file_id=$(echo "$response" | grep -Po '(?<="id":")[^"]*')
    fi

    if [ -n "$file_id" ]; then
        echo -e "${GREEN}✔ Upload successful!${NC}"
        echo -e "${GREEN}Download URL:${NC} https://pixeldrain.com/u/$file_id"
    else
        echo -e "${RED}Upload response:${NC} $response"
    fi
}

# ------------------------------------------------------------------------------
# 4. Temp.sh
# ------------------------------------------------------------------------------
upload_tempsh() {
    echo -e "${CYAN}Started uploading file to Temp.sh...${NC}"
    local response
    response=$(curl -# -F "file=@$FILE_PATH" https://temp.sh/upload)

    echo -e "${GREEN}✔ Upload completed!${NC}"
    echo -e "${GREEN}Download URL:${NC} $response"
}

# ------------------------------------------------------------------------------
# 5. GoFile
# ------------------------------------------------------------------------------
upload_gofile() {
    echo -e "${CYAN}Fetching best available GoFile server...${NC}"
    local server_json
    server_json=$(curl -s --connect-timeout 10 https://api.gofile.io/servers || true)

    local server=""
    if command -v jq &>/dev/null; then
        server=$(echo "$server_json" | jq -r '.data.servers[0].name // .data.serversAllZone[0].name // empty')
    elif command -v python3 &>/dev/null; then
        server=$(echo "$server_json" | python3 -c 'import sys, json; d=json.load(sys.stdin); print(d.get("data",{}).get("servers",[{}])[0].get("name") or d.get("data",{}).get("serversAllZone",[{}])[0].get("name",""))' 2>/dev/null)
    else
        server=$(echo "$server_json" | grep -Po '(?<="name":")[^"]*' | head -n 1)
    fi

    if [ -z "$server" ]; then
        echo -e "${YELLOW}Warning: Could not fetch server dynamically, falling back to 'store3'.${NC}"
        server="store3"
    fi

    echo -e "${CYAN}Uploading to GoFile server [${BOLD}$server${NC}${CYAN}]...${NC}"

    local curl_opts=("-#" "-F" "file=@$FILE_PATH")
    if [ -n "$KEY" ]; then
        curl_opts+=("-F" "token=$KEY")
    fi
    if [ -n "$FOLDER_ID" ]; then
        curl_opts+=("-F" "folderId=$FOLDER_ID")
    fi

    local response
    response=$(curl "${curl_opts[@]}" "https://${server}.gofile.io/contents/uploadfile")

    local download_url=""
    if command -v jq &>/dev/null; then
        download_url=$(echo "$response" | jq -r '.data.downloadPage // empty')
    elif command -v python3 &>/dev/null; then
        download_url=$(echo "$response" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("data",{}).get("downloadPage",""))' 2>/dev/null)
    else
        download_url=$(echo "$response" | grep -Po '(?<="downloadPage":")[^"]*')
    fi

    if [ -n "$download_url" ]; then
        echo -e "${GREEN}✔ GoFile upload successful!${NC}"
        echo -e "${GREEN}Download Page:${NC} ${BOLD}$download_url${NC}"
    else
        echo -e "${RED}Upload failed or invalid response from GoFile:${NC}"
        echo "$response"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# 6. Oshi.at
# ------------------------------------------------------------------------------
upload_oshi() {
    echo -e "${CYAN}Started uploading file to Oshi.at...${NC}"
    local response
    response=$(curl -# -F "file=@$FILE_PATH" https://oshi.at)

    echo -e "${GREEN}✔ Upload completed!${NC}"
    echo -e "${GREEN}Response:${NC}"
    echo "$response"
}

# ------------------------------------------------------------------------------
# 7. SourceForge (FRS High Speed Optimization)
# ------------------------------------------------------------------------------
upload_sourceforge() {
    if [ -z "$USER_NAME" ]; then
        read -p "Please enter SourceForge Username: " USER_NAME
    fi

    if [ -z "$REMOTE_PATH" ]; then
        local detected_codename=""
        if [[ "$FILE_PATH" =~ out/target/product/([^/]+)/ ]]; then
            detected_codename="${BASH_REMATCH[1]}"
        fi

        echo -e "Please enter upload location on SourceForge:"
        if [ -n "$detected_codename" ]; then
            echo -e "${YELLOW}Detected device codename:${NC} ${BOLD}$detected_codename${NC}"
            echo -e "${YELLOW}Note: Format as 'project_name/folder' (e.g. myproject/$detected_codename)${NC}"
        else
            echo -e "${YELLOW}Note: Format as 'project_name/folder' (e.g. myproject/v1.0)${NC}"
        fi
        read -p "Path: " REMOTE_PATH
    fi

    if [ -z "$KEY" ]; then
        KEY=$(read_secret "Please enter SourceForge Password (press Enter to use SSH Key / terminal prompt): ")
    fi

    # Sanitize remote path to avoid duplicate /home/frs/project/ prefixes
    REMOTE_PATH="${REMOTE_PATH#/home/frs/project/}"
    REMOTE_PATH="${REMOTE_PATH#/}"

    if [ -z "$USER_NAME" ] || [ -z "$REMOTE_PATH" ]; then
        echo -e "${RED}Error: Username and target path are required for SourceForge.${NC}"
        exit 1
    fi

    local target_host="frs.sourceforge.net"
    local full_remote_dest="/home/frs/project/${REMOTE_PATH}"
    local project_name
    project_name=$(echo "$REMOTE_PATH" | cut -d'/' -f1)

    echo -e "${CYAN}Preparing SourceForge high-speed upload...${NC}"
    echo -e "${YELLOW}File:${NC} $(basename "$FILE_PATH") ($(du -h "$FILE_PATH" | cut -f1))"
    echo -e "${YELLOW}Target:${NC} ${USER_NAME}@${target_host}:${full_remote_dest}/"

    # High performance SSH options:
    # - IPQoS=throughput: Optimizes TCP buffer windowing for maximum network throughput
    # - Compression=no: Avoids wasting CPU re-compressing zip/iso/rom archives
    # - Optimized Ciphers: Prioritizes fast modern ciphers (ChaCha20-Poly1305, AES-GCM)
    local ssh_opts="ssh -o IPQoS=throughput -o Compression=no -o ServerAliveInterval=15 -o ServerAliveCountMax=6 -o Ciphers=chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com"

    local runner=""
    if [ -n "$KEY" ]; then
        if command -v sshpass &>/dev/null; then
            runner="SSHPASS=\"$KEY\" sshpass -e"
        else
            echo -e "${YELLOW}Note: 'sshpass' not installed. SSH will prompt for password interactively if SSH key is not set up.${NC}"
        fi
    fi

    if command -v rsync &>/dev/null; then
        echo -e "${GREEN}🚀 Utilizing optimized rsync protocol (Maximum speed + resumable)...${NC}"
        if [ -n "$KEY" ] && command -v sshpass &>/dev/null; then
            SSHPASS="$KEY" sshpass -e rsync -avP --info=progress2 --partial --rsync-path="mkdir -p ${full_remote_dest} && rsync" -e "$ssh_opts" "$FILE_PATH" "${USER_NAME}@${target_host}:${full_remote_dest}/"
        else
            rsync -avP --info=progress2 --partial --rsync-path="mkdir -p ${full_remote_dest} && rsync" -e "$ssh_opts" "$FILE_PATH" "${USER_NAME}@${target_host}:${full_remote_dest}/"
        fi
    else
        echo -e "${YELLOW}rsync not detected. Falling back to optimized scp...${NC}"
        if [ -n "$KEY" ] && command -v sshpass &>/dev/null; then
            SSHPASS="$KEY" sshpass -e scp -o IPQoS=throughput -o Compression=no -o ServerAliveInterval=15 -o ServerAliveCountMax=6 -o Ciphers=chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com "$FILE_PATH" "${USER_NAME}@${target_host}:${full_remote_dest}/"
        else
            scp -o IPQoS=throughput -o Compression=no -o ServerAliveInterval=15 -o ServerAliveCountMax=6 -o Ciphers=chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com "$FILE_PATH" "${USER_NAME}@${target_host}:${full_remote_dest}/"
        fi
    fi

    echo -e "${GREEN}✔ Upload to SourceForge completed!${NC}"
    echo -e "${GREEN}Files URL:${NC} https://sourceforge.net/projects/${project_name}/files/${REMOTE_PATH#$project_name/}/"
}

# ------------------------------------------------------------------------------
# 8. VexFiles
# ------------------------------------------------------------------------------
upload_vexfile() {
    if [ -z "$KEY" ]; then
        KEY=$(read_secret "Please enter VexFiles API Key: ")
    fi

    if [ -z "$KEY" ]; then
        echo -e "${RED}Error: VexFiles API token is required.${NC}"
        exit 1
    fi

    echo -e "${CYAN}Started uploading file to VexFiles...${NC}"
    local response
    response=$(curl -# -X POST https://vexfile.com/api/upload/handle \
      -H "Content-Type: multipart/form-data" \
      -F "token=$KEY" \
      -F "file=@$FILE_PATH")

    echo -e "${GREEN}✔ Upload completed!${NC}"
    echo -e "${GREEN}Response:${NC} $response"
}

# Parse Command Line Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)
            FILE_PATH="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        -u|--user)
            USER_NAME="$2"
            shift 2
            ;;
        -p|--path)
            REMOTE_PATH="$2"
            shift 2
            ;;
        -r|--repo)
            GH_REPO="$2"
            shift 2
            ;;
        -k|--key)
            KEY="$2"
            shift 2
            ;;
        --folder)
            FOLDER_ID="$2"
            shift 2
            ;;
        -a|--auto)
            AUTO_DETECT=1
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Auto-detect ROM file if requested or if FILE_PATH is empty
if [ -z "$FILE_PATH" ] || [ "${AUTO_DETECT:-0}" -eq 1 ]; then
    detect_rom_file || true
fi

# Interactive Mode if service or file not provided
if [ -z "$SERVICE" ] || [ -z "$FILE_PATH" ]; then
    show_banner
    echo -e "${BOLD}Select Upload Host:${NC}"
    echo -e "  [1] GitHub Release       ${MAGENTA}[gh auth login]${NC}"
    echo -e "  [2] DevUploads          ${MAGENTA}[API Key]${NC}"
    echo -e "  [3] PixelDrain          ${MAGENTA}[API Key]${NC}"
    echo -e "  [4] Temp.sh             ${MAGENTA}[Anonymous]${NC}"
    echo -e "  [5] GoFile              ${MAGENTA}[Fast Auto Server]${NC}"
    echo -e "  [6] Oshi.at             ${MAGENTA}[Anonymous]${NC}"
    echo -e "  [7] SourceForge (FRS)   ${GREEN}[High-Speed rsync]${NC}"
    echo -e "  [8] VexFiles            ${MAGENTA}[API Key]${NC}"
    echo ""

    if [ -z "$SERVICE" ]; then
        read -p "Enter number [1-8]: " SERVICE
    fi

    if [ -z "$FILE_PATH" ]; then
        read -e -p "Please enter file path: " FILE_PATH
    fi
fi

check_file

# Normalize Service selection
case "$SERVICE" in
    1|github)
        upload_github
        ;;
    2|devuploads)
        upload_devuploads
        ;;
    3|pixeldrain)
        upload_pixeldrain
        ;;
    4|temp|temp.sh)
        upload_tempsh
        ;;
    5|gofile)
        upload_gofile
        ;;
    6|oshi|oshi.at)
        upload_oshi
        ;;
    7|sourceforge|sf)
        upload_sourceforge
        ;;
    8|vexfile|vexfiles)
        upload_vexfile
        ;;
    *)
        echo -e "${RED}Error: Invalid service selected: '$SERVICE'${NC}"
        exit 1
        ;;
esac
