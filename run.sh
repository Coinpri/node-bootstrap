#!/bin/bash

# Initialize the flag indicating whether to skip the OS check
skip_os_check=false

# Process command-line options
while getopts "f" opt; do
  case $opt in
    f)
      skip_os_check=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Check the OS version if the -f flag is not set
if ! $skip_os_check; then
  if grep -q 'Ubuntu 22.04' /etc/os-release; then
      echo "Running on Ubuntu 22.04, proceeding..."
  else
      echo "This script is intended for Ubuntu 22.04. Exiting."
      exit 1
  fi
else
  echo "Skipping OS check as per -f flag."
fi

# Your script's operations go here
