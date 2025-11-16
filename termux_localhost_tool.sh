#!/usr/bin/env bash
# termux_localhost_tool.sh — Updated: menu numbers 1-6,7,8; short create message
# v1.0 patched

IFS=$'\n\t'

# ---------- Visuals ----------
CSI="\033["; RESET="${CSI}0m"; BOLD="${CSI}1m"
BLACK="${CSI}30m"; RED="${CSI}31m"; GREEN="${CSI}32m"; YELLOW="${CSI}33m"
BLUE="${CSI}34m"; MAGENTA="${CSI}35m"; CYAN="${CSI}36m"; WHITE="${CSI}37m"

EMOJI_COMPUTER="🧑‍💻"; EMOJI_PHP="🐘"; EMOJI_HTML="🧱"; EMOJI_PYTHON="🐍"
EMOJI_STOP="🛑"; EMOJI_STATUS="📊"; EMOJI_TUNNEL="🌐"; EMOJI_FOLDER="📁"
EMOJI_EXIT="🚪"; EMOJI_OK="✅"; EMOJI_WARN="⚠️"; EMOJI_ERROR="❌"; EMOJI_PUBLIC="🌍"; EMOJI_BACK="🔙"

# ---------- Paths ----------
HOME_DIR="$HOME"
BIN_DIR="$HOME_DIR/bin"
SHARED="$HOME_DIR/storage/shared"
if [ -d "$SHARED" ]; then
  STORAGE_BASE="$SHARED"
else
  STORAGE_BASE="$HOME_DIR"
fi
ROOT_DIR="$STORAGE_BASE/localhost"
PIDS_DIR="$HOME_DIR/.localhost_tool/pids"
LOG_DIR="$HOME_DIR/.localhost_tool/logs"
DEBUG_LOG="$HOME_DIR/.localhost_tool/debug.log"

mkdir -p "$BIN_DIR" "$PIDS_DIR" "$LOG_DIR" "$(dirname "$DEBUG_LOG")" >/dev/null 2>&1 || true
echo "tool start: $(date -u)" >> "$DEBUG_LOG" 2>/dev/null || true

# ---------- Samples ----------
PHP_INDEX_CONTENT="<?php phpinfo(); ?>"
HTML_INDEX_CONTENT="<!doctype html><html><head><meta charset='utf-8'><title>Local HTML</title></head><body><h1>Local HTML Server</h1><p>Sample index.html</p></body></html>"
PY_APP_CONTENT="# Simple Python static server\nimport http.server, socketserver\nPORT = 8000\nHandler = http.server.SimpleHTTPRequestHandler\nwith socketserver.TCPServer(('0.0.0.0', PORT), Handler) as httpd:\n    print('Serving at port', PORT)\n    httpd.serve_forever()\n"

# ---------- Printers ----------
info()    { printf "%b\n" "${BLUE}${BOLD}${EMOJI_COMPUTER}  $*${RESET}"; }
success() { printf "%b\n" "${GREEN}${EMOJI_OK}  $*${RESET}"; }
warning() { printf "%b\n" "${YELLOW}${EMOJI_WARN}  $*${RESET}"; }
terr_short(){ printf "%b\n" "${RED}${EMOJI_ERROR}  Invalid input — please enter a number${RESET}"; }
terr()    { printf "%b\n" "${RED}${EMOJI_ERROR}  $*${RESET}"; }
public_msg(){ printf "%b\n" "${CYAN}${EMOJI_PUBLIC}  $*${RESET}"; }

# ---------- File helpers ----------
pidfile_for()  { printf "%s" "$PIDS_DIR/$1.pid"; }
portfile_for() { printf "%s" "$PIDS_DIR/$1.port"; }
logfile_for()  { printf "%s" "$LOG_DIR/$1.log"; }

# ---------- Utilities ----------
_find_pid_by_pattern() {
  local pattern="$1"
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -f "$pattern" 2>/dev/null | head -n1 || true
  else
    ps aux 2>/dev/null | grep -F "$pattern" | grep -v grep | awk '{print $2}' | head -n1 || true
  fi
}

ports_for_pid() {
  local pid="$1"; local out=""
  if command -v ss >/dev/null 2>&1; then
    out=$(ss -ltnp 2>/dev/null | awk -v pid="$pid" '$0 ~ "pid="pid {print $4}' | tr '\n' ' ')
  elif command -v netstat >/dev/null 2>&1; then
    out=$(netstat -ltnp 2>/dev/null | awk -v pid="$pid" '$0 ~ pid {print $4}' | tr '\n' ' ')
  elif command -v lsof >/dev/null 2>&1; then
    out=$(lsof -Pan -p "$pid" -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1{print $9}' | tr '\n' ' ')
  fi
  printf "%s" "$out"
}

_start_background() {
  local svc="$1"; shift
  local port="$1"; shift
  local cmd=( "$@" )
  if command -v setsid >/dev/null 2>&1; then
    setsid "${cmd[@]}" >"$(logfile_for "$svc")" 2>&1 &
    pid=$!
  else
    nohup "${cmd[@]}" >"$(logfile_for "$svc")" 2>&1 &
    pid=$!
  fi
  sleep 0.12
  if ! kill -0 "$pid" 2>/dev/null; then
    local found=$(_find_pid_by_pattern "${cmd[*]}")
    [ -n "${found:-}" ] && pid="$found"
  fi
  printf "%s" "$pid"
}

ensure_dirs_and_samples() {
  mkdir -p "$ROOT_DIR/php" "$ROOT_DIR/html" "$ROOT_DIR/python" "$PIDS_DIR" "$LOG_DIR" >/dev/null 2>&1 || true
  [ ! -f "$ROOT_DIR/php/index.php" ] && printf "%s" "$PHP_INDEX_CONTENT" > "$ROOT_DIR/php/index.php"
  [ ! -f "$ROOT_DIR/html/index.html" ] && printf "%s" "$HTML_INDEX_CONTENT" > "$ROOT_DIR/html/index.html"
  [ ! -f "$ROOT_DIR/python/app.py" ] && printf "%s" "$PY_APP_CONTENT" > "$ROOT_DIR/python/app.py"
}

ensure_storage_permission() {
  if [ -d "$SHARED" ] && [ -w "$SHARED" ]; then
    STORAGE_BASE="$SHARED"; ROOT_DIR="$STORAGE_BASE/localhost"; return 0
  fi

  echo
  printf "%b\n" "${YELLOW}${EMOJI_WARN}  Termux storage not granted or not available.${RESET}"
  read -r -p "Run termux-setup-storage now? (y = run / n = use fallback ~/localhost): " ans
  case "$ans" in
    y|Y)
      termux-setup-storage >/dev/null 2>&1 || true
      sleep 2
      if [ -d "$SHARED" ] && [ -w "$SHARED" ]; then
        STORAGE_BASE="$SHARED"; ROOT_DIR="$STORAGE_BASE/localhost"
        success "Storage permission granted — using $STORAGE_BASE"
        return 0
      else
        warning "Permission not detected. Using fallback: ~/localhost"
        STORAGE_BASE="$HOME_DIR"; ROOT_DIR="$STORAGE_BASE/localhost"; return 0
      fi
      ;;
    *)
      warning "Using fallback: ~/localhost"
      STORAGE_BASE="$HOME_DIR"; ROOT_DIR="$STORAGE_BASE/localhost"; return 0
      ;;
  esac
}

# ---------- Start/Stop/Status/Tunnel ----------
start_php() {
  local port="${1:-8080}"
  ensure_dirs_and_samples
  if ! command -v php >/dev/null 2>&1; then terr "php not installed. Install: pkg install php"; return 1; fi
  pid=$(_start_background php "$port" php -S 127.0.0.1:"$port" -t "$ROOT_DIR/php")
  if [ -n "${pid:-}" ]; then
    echo "$pid" > "$(pidfile_for php)"; echo "$port" > "$(portfile_for php)"
    success "PHP started — Local: http://127.0.0.1:$port (PID $pid)"
  else
    terr "Failed to start PHP. See $(logfile_for php)"
  fi
}

start_html() {
  local port="${1:-8081}"
  ensure_dirs_and_samples
  local pycmd; pycmd=$(command -v python3 || command -v python || true)
  if [ -z "${pycmd:-}" ]; then terr "Python not installed. Install: pkg install python"; return 1; fi
  pid=$(_start_background html "$port" "$pycmd" -m http.server "$port" --bind 127.0.0.1 -d "$ROOT_DIR/html")
  if [ -n "${pid:-}" ]; then
    echo "$pid" > "$(pidfile_for html)"; echo "$port" > "$(portfile_for html)"
    success "HTML started — Local: http://127.0.0.1:$port (PID $pid)"
  else
    terr "Failed to start HTML. See $(logfile_for html)"
  fi
}

start_python() {
  local port="${1:-8000}"
  ensure_dirs_and_samples
  local pycmd; pycmd=$(command -v python3 || command -v python || true)
  if [ -z "${pycmd:-}" ]; then terr "Python not installed. Install: pkg install python"; return 1; fi
  if [ -f "$ROOT_DIR/python/app.py" ]; then
    pid=$(_start_background python "$port" "$pycmd" "$ROOT_DIR/python/app.py")
  else
    pid=$(_start_background python "$port" "$pycmd" -m http.server "$port" --bind 127.0.0.1 -d "$ROOT_DIR/python")
  fi
  if [ -n "${pid:-}" ]; then
    echo "$pid" > "$(pidfile_for python)"; echo "$port" > "$(portfile_for python)"
    success "Python started — Local: http://127.0.0.1:$port (PID $pid)"
  else
    terr "Failed to start Python. See $(logfile_for python)"
  fi
}

stop_service() {
  local svc="$1"
  local pidf; pidf=$(pidfile_for "$svc")
  if [ -f "$pidf" ]; then
    local pid; pid=$(cat "$pidf" 2>/dev/null || true)
    if [ -n "${pid:-}" ]; then kill "$pid" 2>/dev/null || true; fi
    rm -f "$pidf" "$(portfile_for "$svc")" 2>/dev/null || true
    warning "Stopped: $svc"
  else
    terr "Not running: $svc"
  fi
}

# show_status is NON-BLOCKING (main menu will pause once)
show_status() {
  clear
  echo
  printf "%b\n" "${CYAN}${BOLD}${EMOJI_STATUS}  Status (PID & ports)${RESET}"
  for s in php html python tunnel; do
    pidf=$(pidfile_for "$s")
    if [ -f "$pidf" ]; then
      pid=$(cat "$pidf" 2>/dev/null || true)
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        port=""
        if [ -f "$(portfile_for "$s")" ]; then
          port=$(cat "$(portfile_for "$s")" 2>/dev/null || true)
        else
          port=$(ports_for_pid "$pid" 2>/dev/null || true)
        fi
        if [ "$s" = "tunnel" ]; then
          printf "%b\n" " ${CYAN}${EMOJI_TUNNEL}  tunnel running (PID $pid)${RESET}"
          logfile=$(logfile_for tunnel)
          if [ -f "$logfile" ]; then
            url=$(grep -Eo "https?://[a-zA-Z0-9./?=_-]*trycloudflare.com[^\" ]*|https?://[a-z0-9-]+\\.(cloudflared|cfargotunnel|cloudflare-tunnel)\\.[a-z]+[^\" ]*" "$logfile" 2>/dev/null | head -n1 || true)
            [ -n "$url" ] && printf "    %b %s\n" "${CYAN}Public URL:${RESET}" "$url"
          fi
        else
          printf "%b\n" " ${GREEN}${EMOJI_OK}  $s running (PID $pid) — ports: ${port:-unknown}${RESET}"
        fi
      else
        printf "%b\n" " ${YELLOW}${EMOJI_WARN}  $s stopped${RESET}"
      fi
    else
      printf "%b\n" " ${YELLOW}${EMOJI_WARN}  $s stopped${RESET}"
    fi
  done
  echo
  # NO read here — main menu will do the single Enter pause
}

expose_port() {
  local port="${1:-8080}"
  if ! command -v cloudflared >/dev/null 2>&1; then terr "cloudflared not installed. Install: pkg install cloudflared"; return 1; fi
  ensure_dirs_and_samples
  logfile=$(logfile_for tunnel)
  nohup cloudflared tunnel --url "http://127.0.0.1:${port}" >"$logfile" 2>&1 &
  pid=$!
  sleep 0.5
  if ! kill -0 "$pid" 2>/dev/null; then pid=$(_find_pid_by_pattern "cloudflared"); fi
  [ -n "${pid:-}" ] && echo "$pid" > "$(pidfile_for tunnel)"
  echo "$port" > "$(portfile_for tunnel)"

  attempts=0; max_attempts=30; url=""
  while [ $attempts -lt $max_attempts ]; do
    sleep 1; attempts=$((attempts+1))
    if [ -f "$logfile" ]; then
      url=$(grep -Eo "https?://[a-zA-Z0-9./?=_-]*trycloudflare.com[^\" ]*|https?://[a-z0-9-]+\\.(cloudflared|cfargotunnel|cloudflare-tunnel)\\.[a-z]+[^\" ]*" "$logfile" 2>/dev/null | head -n1 || true)
    fi
    [ -n "$url" ] && break
  done

  if [ -n "$url" ]; then
    public_msg "Public URL: $url"
    if command -v termux-clipboard-set >/dev/null 2>&1; then
      printf "%s" "$url" | termux-clipboard-set >/dev/null 2>&1 && info "Public URL copied to clipboard."
    fi
  else
    warning "Public URL not detected yet. Check log: $logfile"
    echo "---- last 40 lines ----"
    tail -n 40 "$logfile" 2>/dev/null || true
    echo "-----------------------"
  fi
}

create_folders() {
  ensure_dirs_and_samples
  # short success message only (no path)
  success "Created/verified folders"
  echo
}

# start-server installer
install_shortcut() {
  local wrapper="$BIN_DIR/start-server"
  if [ ! -f "$wrapper" ]; then
    cat > "$wrapper" <<'SH'
#!/usr/bin/env bash
exec bash "$HOME/termux_localhost_tool.sh" "$@"
SH
    chmod +x "$wrapper" 2>/dev/null || true
    if ! grep -qxF 'export PATH="$HOME/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
      echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.profile"
    fi
    info "Shortcut created: start-server → $HOME/termux_localhost_tool.sh"
    info "Open a new Termux session or run: source ~/.profile to use start-server"
  fi
}

# ---------- Input parsing ----------
_trim_lower() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf "%s" "$(printf "%s" "$s" | tr '[:upper:]' '[:lower:]')"
}

parse_choice() {
  local raw="$1"
  local s
  s=$(_trim_lower "$raw")
  # empty -> return empty (silently re-show)
  if [ -z "$s" ]; then
    printf ""
    return
  fi
  # numeric direct
  if printf "%s" "$s" | grep -qE '^[0-9]+$'; then
    printf "%s" "$s"; return
  fi
  case "$s" in
    "php" | "start php" | "start-php" | "startphp" ) printf "1" ;;
    "html" | "start html" | "start-html" | "starthtml" ) printf "2" ;;
    "python" | "start python" | "start-python" | "startpython" ) printf "3" ;;
    "stop" | "stop service" | "stop-service" ) printf "4" ;;
    "status" | "show status" | "stat" ) printf "5" ;;
    "tunnel" | "cloudflared" | "expose" | "expose tunnel" ) printf "6" ;;
    "create" | "create folders" | "folders" | "folder" | "create folder" | "seven" ) printf "7" ;;
    "exit" | "quit" | "bye" | "close" | "eight" ) printf "8" ;;
    * ) printf "" ;;
  esac
}

# ---------- Banner ----------
print_banner() {
  cols=$(tput cols 2>/dev/null || echo 80)
  printf "%b\n" "${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
  printf "%b\n" "${GREEN}${BOLD}🧩   Simple • Powerful • Automated   ${RESET}"
  printf "%b\n" "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}"
  left="deplove by @error_rat"; right="version 1.0"
  l_len=${#left}; r_len=${#right}
  space=$(( cols - l_len - r_len - 2 ))
  if [ "$space" -lt 1 ]; then space=2; fi
  printf "%b%s%b\n\n" "${WHITE}${BOLD}${left}${RESET}" "$(printf ' %.0s' $(seq 1 $space))" "${WHITE}${BOLD}${right}${RESET}"
}

# ---------- Main menu ----------
main_menu() {
  ensure_storage_permission
  ensure_dirs_and_samples
  install_shortcut

  while true; do
    clear
    print_banner
    printf "%b\n" "${BOLD}1.${RESET} ${BOLD}${EMOJI_PHP}  Start PHP server${RESET}"
    printf "%b\n" "${BOLD}2.${RESET} ${BOLD}${EMOJI_HTML}  Start HTML server${RESET}"
    printf "%b\n" "${BOLD}3.${RESET} ${BOLD}${EMOJI_PYTHON}  Start Python server${RESET}"
    printf "%b\n" "${BOLD}4.${RESET} ${BOLD}${EMOJI_STOP}  Stop a service${RESET}"
    printf "%b\n" "${BOLD}5.${RESET} ${BOLD}${EMOJI_STATUS}  Status (PID & ports)${RESET}"
    printf "%b\n" "${BOLD}6.${RESET} ${BOLD}${EMOJI_TUNNEL}  Expose via Cloudflare Tunnel${RESET}"
    printf "%b\n" "${BOLD}7.${RESET} ${BOLD}${EMOJI_FOLDER}  Create folders & samples${RESET}"
    printf "%b\n" "${BOLD}8.${RESET} ${BOLD}${EMOJI_EXIT}  Exit${RESET}"
    echo

    read -r -p $'\nChoose an option (1-8): ' raw_input || raw_input=""
    choice=$(parse_choice "$raw_input")

    # empty Enter -> reprint menu without message
    if [ -z "$raw_input" ] || [ -z "$choice" ]; then
      if [ -z "$(printf "%s" "$raw_input" | tr -d '[:space:]')" ]; then
        continue
      fi
      if [ -n "$(printf "%s" "$raw_input" | tr -d '[:space:]')" ] && [ -z "$choice" ]; then
        terr_short
        printf "\nPress Enter to try again..."
        read -r _
        continue
      fi
    fi

    case "$choice" in
      1) read -r -p "Port (default 8080): " p; p="${p:-8080}"; start_php "$p" ;;
      2) read -r -p "Port (default 8081): " p; p="${p:-8081}"; start_html "$p" ;;
      3) read -r -p "Port (default 8000): " p; p="${p:-8000}"; start_python "$p" ;;
      4) read -r -p "Stop which? (php/html/python/tunnel/all): " s
         if [ "$s" = "all" ]; then for svc in php html python tunnel; do stop_service "$svc"; done; else stop_service "$s"; fi ;;
      5) show_status ;;
      6) read -r -p "Port to expose (default 8080): " p; p="${p:-8080}"; expose_port "$p" ;;
      7) create_folders ;;
      8) printf "%b\n" "${MAGENTA}👋 Goodbye!${RESET}"; exit 0 ;;
      *) terr "Unexpected choice: $choice" ;;
    esac

    # central single pause (one Enter returns to menu)
    printf "\nPress Enter to return to menu..."
    read -r _
  done
}

# ---------- Run ----------
main_menu
