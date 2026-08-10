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
