#!/bin/bash

UUID='YOUR_UUID'
DOMAIN='YOUR_DOMAIN'
REMARKS='YOUR_REMARKS'

cx_output="$($HOME/cx get --interpreter=nodejs --json)"
if ! echo "$cx_output" | grep -q "UUID"; then
    $HOME/cx create --json --interpreter=nodejs --user=`whoami` --app-root=$HOME/domains/$DOMAIN/public_html --app-uri=/ --version=22 --app-mode=Production --startup-file=app.js --env-vars='{"UUID":"'$UUID'","DOMAIN":"'$DOMAIN'","REMARKS":"'$REMARKS'","WEB_SHELL":"on"}'
    $HOME/nodevenv/domains/$DOMAIN/public_html/22/bin/npm install
    rm -rf $HOME/.npm/_logs/*.log
fi

# Clear log file
> /home/$USER/app/backup.log

# Performing health check via curl
echo `date`" -- curl https://$DOMAIN/hello"
curl https://$DOMAIN/hello
echo

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
