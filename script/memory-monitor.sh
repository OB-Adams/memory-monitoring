#!/usr/bin/env bash

set -euo pipefail

WARN_PCT=75         
CRIT_PCT=90        
SWAP_WARN_PCT=50  
TOP_N=5          
LOGFILE=""      
QUIET=0        
SCRIPT_NAME=$(basename "$0")

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [options]
 
Options:
  -w PCT   Warning threshold for RAM used, percent (default: ${WARN_PCT})
  -c PCT   Critical threshold for RAM used, percent (default: ${CRIT_PCT})
  -s PCT   Swap warning threshold, percent (default: ${SWAP_WARN_PCT})
  -n NUM   Number of top memory-consuming processes to show (default: ${TOP_N})
  -l FILE  Append a timestamped log line to FILE
  -q       Quiet: suppress the human-readable report, keep exit code + log
  -h       Show this help
 
Exit codes: 0=OK  1=WARNING  2=CRITICAL  3=script error
 
Examples:
  ${SCRIPT_NAME}                          # quick interactive check
  ${SCRIPT_NAME} -w 80 -c 95 -n 10          # custom thresholds, top 10 procs
  ${SCRIPT_NAME} -q -l /var/log/mem-monitor.log   # cron-friendly
EOF
}

while getopts ":w:c:s:n:l:qh" opt; do
    case "${opt}" in
        w) WARN_PCT=${OPTARG} ;;
        c) CRIT_PCT=${OPTARG} ;;
        s) SWAP_WARN_PCT=${OPTARG} ;;
        n) TOP_N=${OPTARG} ;;
        l) LOGFILE=${OPTARG} ;;
        q) QUIET=1 ;;
        h) usage; exit 0 ;;
        \?) echo "Unknown option: -${OPTARG}" >&2; usage; exit 3 ;;
        :) echo "Option -${OPTARG} requires an argument" >&2; usage; exit 3 ;;
    esac
done

if ! command -v free >/dev/null 2>&1; then
	echo "Error: 'free' command not found (procps package)." >&2
	exit 3
fi

declare -A mem
while read -r key value _unit; do
	key=${key%:}
	mem[$key]=$value
done < /proc/meminfo

mem_total_kb=${mem[MemTotal]:-0}
mem_avail_kb=${mem[MemAvailable]:-0}
swap_total_kb=${mem[SwapTotal]:-0}
swap_free_kb=${mem[SwapFree]:-0}

if [[ "${mem_total_kb}" -eq 0 ]]; then
	echo "Error: could not read MemTotal from /proc/meminfo." >&2
	exit 3
fi

mem_used_kb=$(( mem_total_kb - mem_avail_kb ))
mem_used_pct=$(( 100 * mem_used_kb / mem_total_kb))

swap_used_pct=0
if [[ "${swap_total_kb}" -gt 0 ]]; then
	swap_used_kb=$(( swap_total_kb - swap_free_kb ))
	swap_used_pct=$(( 100 * swap_used_kb / swap_total_kb ))
fi

to_human() {
    local kb=$1
    if (( kb >= 1048576 )); then
        awk -v k="${kb}" 'BEGIN{printf "%.1fG", k/1048576}'
    else
        awk -v k="${kb}" 'BEGIN{printf "%.0fM", k/1024}'
    fi
}

status="OK"
exit_code=0


if (( mem_used_pct >= CRIT_PCT )); then
	status="CRITICAL"
	exit_code=2
elif (( mem_used_pct >= WARN_PCT )); then
	status="WARNING"
	exit_code=1
fi

if (( swap_total_kb > 0 && swap_used_pct >= SWAP_WARN_PCT && exit_code < 1 )); then
    status="WARNING"
    exit_code=1
fi

timestamp=$(date '+%Y-%m-%d %H:%M:%S')

top_procs=$(ps -eo pid,user,%mem,rss,comm --sort=-%mem | head -n $((TOP_N + 1)))

report=$(cat <<EOF
[${timestamp}] mem-monitor: ${status}
  RAM : $(to_human "${mem_used_kb}") / $(to_human "${mem_total_kb}") used (${mem_used_pct}%)  [warn >=${WARN_PCT}%, crit >=${CRIT_PCT}%]
  Swap: $(to_human "$(( swap_total_kb - swap_free_kb ))") / $(to_human "${swap_total_kb}") used (${swap_used_pct}%)  [warn >=${SWAP_WARN_PCT}%]

  Top ${TOP_N} memory-consuming processes:
$(echo "${top_procs}" | tail -n +2 | awk '{printf "    %-8s %-10s %5s%%  %8s KB  %s\n", $1, $2, $3, $4, $5}')
EOF
)

if [[ "${QUIET}" -eq 0 ]]; then
    echo "${report}"
fi
 
if [[ -n "${LOGFILE}" ]]; then
    {
        echo "${report}"
        echo
    } >> "${LOGFILE}"
fi
 
exit "${exit_code}"
