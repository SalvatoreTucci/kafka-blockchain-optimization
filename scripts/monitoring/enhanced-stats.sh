#!/bin/bash
# Enhanced Docker Stats Collection

OUTPUT_FILE="$1"
DURATION="${2:-60}"  # Default 60 seconds

echo "Collecting enhanced stats for ${DURATION} seconds..."
echo "timestamp,cpu_percent,mem_usage_mb,mem_limit_gb,mem_percent,net_in_mb,net_out_mb,block_in_mb,block_out_mb" > "$OUTPUT_FILE"

END_TIME=$(($(date +%s) + DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    docker stats kafka --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" | \
    tail -1 | \
    awk -v ts="$(date +%s)" '{
        # Parse values
        cpu=$1
        mem_usage=$2
        mem_limit=$4
        mem_pct=$5
        net_in=$6
        net_out=$8
        block_in=$9
        block_out=$11
        
        # Convert to MB
        gsub(/[^0-9.]/, "", net_in)
        gsub(/[^0-9.]/, "", net_out)
        gsub(/[^0-9.]/, "", block_in)
        gsub(/[^0-9.]/, "", block_out)
        gsub(/%/, "", cpu)
        gsub(/%/, "", mem_pct)
        
        printf "%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n", 
               ts, cpu, mem_usage, mem_limit, mem_pct, net_in, net_out, block_in, block_out
    }' >> "$OUTPUT_FILE"
    
    sleep 5
done

echo "Stats collection complete: $OUTPUT_FILE"