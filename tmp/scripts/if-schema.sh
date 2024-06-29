#!/bin/bash

# Get the list of network connections
connections=$(nmcli -t -f NAME,DEVICE con show)

# Check if any connections have the name 'System eth'
if echo "$connections" | grep -q 'System eth'; then
  echo "Found connections named 'System eth'. Renaming..."

  # Loop through each connection and rename it
  while read -r line; do
    connection=$(echo "$line" | cut -d: -f1)
    device=$(echo "$line" | cut -d: -f2)
    
    if [[ $connection == *"System eth"* ]]; then
      new_name=$(echo "$connection" | sed 's/System eth/eth/')
      
      # Rename the connection and associate it with the correct device
      nmcli con modify "$connection" connection.id "$new_name" ifname "$device"
      echo "Renamed connection '$connection' to '$new_name' and associated it with device '$device'"
    fi
  done <<< "$connections"

  echo "Connections renamed successfully."
else
  echo "No connections named 'System eth' found."
fi

# Check if any connections have the name 'System eth'
if echo "$connections" | grep -q 'Wired connection '; then
  echo "Found connections named 'Wired connection '. Renaming..."

  # Loop through each connection and rename it
  while read -r line; do
    connection=$(echo "$line" | cut -d: -f1)
    device=$(echo "$line" | cut -d: -f2)
    
    if [[ $connection == *"Wired connection"* ]]; then
      new_name=$(echo "$connection" | sed 's/Wired connection /eth/')
      
      # Rename the connection and associate it with the correct device
      nmcli con modify "$connection" connection.id "$new_name" ifname "$device"
      echo "Renamed connection '$connection' to '$new_name' and associated it with device '$device'"
    fi
  done <<< "$connections"

  echo "Connections renamed successfully."
else
  echo "No connections named 'Wired connection' found."
fi
