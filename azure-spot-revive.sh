#!/bin/bash

# Configuration
RESOURCE_GROUP="YourResourceGroupName"
VM_NAME="YourSpotVmName"
RETRY_DELAY=60
CHECK_INTERVAL=300

echo "Starting Azure Spot VM Reviver for $VM_NAME..."

while true; do
    # 1. Get the current power state of the VM
    # We suppress errors in case the API glitches, and pull just the PowerState string
    STATUS=$(az vm get-instance-view -g "$RESOURCE_GROUP" -n "$VM_NAME" \
        --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
        -o tsv 2>/dev/null)
    
    # 2. Evaluate the status
    if [[ "$STATUS" == "VM running" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $VM_NAME is happily running. Sleeping for 5 minutes..."
        sleep $CHECK_INTERVAL

    elif [[ "$STATUS" == "VM deallocated" || "$STATUS" == "VM stopped" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $VM_NAME has been evicted or stopped! Attempting to revive..."
        
        # Try to start the VM. Capture both standard output and error.
        OUTPUT=$(az vm start -g "$RESOURCE_GROUP" -n "$VM_NAME" 2>&1)
        EXIT_CODE=$?

        # 3. Handle the result of the start attempt
        if [ $EXIT_CODE -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Success! The Spot VM has been allocated and is booting up."
            sleep $RETRY_DELAY
        elif echo "$OUTPUT" | grep -qi -E "AllocationFailed|OverconstrainedAllocationRequest|ZonalAllocationFailed"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Azure is out of Spot capacity or the price is too high. Retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] An unexpected error occurred:"
            echo "$OUTPUT"
            echo "Pausing for $RETRY_DELAY seconds before trying again..."
            sleep $RETRY_DELAY
        fi

    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Unknown status: '$STATUS'. Retrying in 60 seconds..."
        sleep 60
    fi
done
