#!/bin/bash

# Clear log file
> /home/$USER/app/backup.log

# Performing health check via curl
echo `date`" -- curl https://YOUR_DOMAIN/hello"
curl https://YOUR_DOMAIN/hello

# Cleaning disk space
rm -rf /home/$USER/Maildir/*

# Cleaning process
PROCESS_NAME="lsnode"
PIDS=($(pgrep "$PROCESS_NAME"))
if [ ${#PIDS[@]} -le 1 ]; then
    echo "Process count is ${#PIDS[@]}, no action needed"
    exit 0
fi
echo "Found ${#PIDS[@]} instances of $PROCESS_NAME"

declare -A START_TIMES
for pid in "${PIDS[@]}"; do
    START_TICKS=$(awk '{print $22}' /proc/$pid/stat)
    HZ=$(getconf CLK_TCK)
    BOOT_TIME=$(awk '/btime/ {print $2}' /proc/stat)
    START_SECONDS=$((BOOT_TIME + START_TICKS / HZ))
    START_TIMES[$pid]=$START_SECONDS
done

SORTED_PIDS=($(for pid in "${!START_TIMES[@]}"; do
    echo "$pid ${START_TIMES[$pid]}"
done | sort -k2n | awk '{print $1}'))

for ((i=0; i<${#SORTED_PIDS[@]}-1; i++)); do
    OLD_PID=${SORTED_PIDS[$i]}
    echo "Killing old $PROCESS_NAME process PID $OLD_PID"
    kill "$OLD_PID"
done

echo "Cleanup complete. Remaining PID: ${SORTED_PIDS[-1]}"
