# linux-memory-monitor

A small bash tool that reports RAM/swap usage on a Linux host, flags
warning/critical thresholds, and lists the top memory-consuming processes.
Written for cron/systemd timers as much as interactive use, exit codes are
monitoring-friendly.

## Layout

```
.
├── logs/            # runtime log output (gitignored, not tracked)
├── script/
│   └── memory-monitor.sh
└── README.md
```

## Why MemAvailable, not MemFree

`free -m` output is easy to misread. `MemFree` looks alarmingly low on a
healthy system because Linux uses "free" RAM for disk buffers/cache — that
memory is reclaimed instantly if an application needs it. `MemAvailable`
(in `/proc/meminfo` since kernel 3.14) is the kernel's own estimate of how
much memory is actually available for new applications without swapping.
This script reads `MemAvailable` directly from `/proc/meminfo` rather than
parsing `free` output, so `used = MemTotal - MemAvailable`.

## Usage

```bash
chmod +x script/mem-monitor.sh
./script/mem-monitor.sh                          # quick interactive check
./script/mem-monitor.sh -w 80 -c 95 -n 10        # custom thresholds, top 10 procs
./script/mem-monitor.sh -q -l logs/mem-log       # cron-friendly, logs to file
```

```
Options:
  -w PCT   Warning threshold for RAM used, percent (default: 75)
  -c PCT   Critical threshold for RAM used, percent (default: 90)
  -s PCT   Swap warning threshold, percent (default: 50)
  -n NUM   Number of top memory-consuming processes to show (default: 5)
  -l FILE  Append a timestamped log line to FILE
  -q       Quiet: suppress the human-readable report, keep exit code + log
  -h       Show this help
```

### Exit codes

| Code | Meaning  |
|------|----------|
| 0    | OK       |
| 1    | WARNING  |
| 2    | CRITICAL |
| 3    | Script error (bad flags, missing tools) |

These are chosen so the script drops straight into cron + a mailer, a
Nagios/Icinga-style check, or a systemd timer with `OnFailure=`.

## Example output

```
[2026-08-09 14:02:11] mem-monitor: WARNING
  RAM : 2.9G / 3.8G used (77%)  [warn >=75%, crit >=90%]
  Swap: 120M / 512M used (23%)  [warn >=50%]

  Top 5 memory-consuming processes:
    1842     www-data     12.4%   482000 KB  node
    993      postgres      8.1%   315200 KB  postgres
    ...
```

## Running on a schedule

Cron, every 5 minutes, logging quietly and alerting via mail on
warning/critical:

```cron
*/5 * * * * /opt/scripts/script/mem-monitor.sh -q -l /opt/scripts/logs/mem-log || \
    mail -s "mem-monitor: $(hostname) memory alert" you@example.com < /opt/scripts/logs/mem-log
```

Or as a systemd timer/service pair (`mem-monitor.timer` /
`mem-monitor.service`) if you want journald logging and `OnFailure=`
handling instead of mail.

## Possible next steps

- A companion `swap-setup.sh` to create/enable a swapfile (`fdisk`,
  `mkswap`, `swapon`, persist in `/etc/fstab`) — common real-world task.
- systemd unit files for timer-based scheduling instead of cron.
- Push metrics to a monitoring backend (Prometheus node_exporter textfile
  collector, or just structured JSON output) instead of/alongside the log.
