#!/bin/bash
# This is a script you can modify and use to create the virtual gpus start the VM and launch looking glass.
# Note that you should change the IDs of the mdevctl vGPUs and the name of the VM "win10"


    exit_handler() {
        exit  # gets caught by trap and goes to terminator
    }
    terminater(){
        echo
        echo "Please turn off the machine from the virt-manager program"
        exit  # Exits normally
    }
trap "terminater" SIGINT SIGTERM

# Ask for password upfront
sudo -v

echo "This will create Virtual GPUs, start the VM, and run looking glass to view it."
echo "Please configure the VM, for example, its USB devices, from the virt-manager program"

echo "Creating Virtual GPUs..."

# Generate UUIDs
uuid1="ce851576-7e81-46f1-96e1-718da691e53e" # generated with uuidgen
uuid2="b761f485-1eac-44bc-8ae6-2a3569881a1a"
# Define device profiles
profile="nvidia-333" # (3GB profile, need to divide evenly, so I get two profiles for my 6GB graphics driver)
# delete all existing ones
uuids=$(sudo mdevctl list -d | awk '{print $1}')
for uuid in $uuids; do
    echo $uuid
    sudo mdevctl undefine --uuid $uuid
    sudo mdevctl stop --uuid $uuid
done
# Start and define mdev devices
sudo bash -c "
    mdevctl start -u $uuid1 -p 0000:01:00.0 --type $profile
    mdevctl start -u $uuid2 -p 0000:01:00.0 --type $profile
    mdevctl define --auto --uuid $uuid1
    mdevctl define --auto --uuid $uuid2
"

# Sometimes LG fails, this prevents that
sudo touch /dev/shm/looking-glass
sudo chmod 777 /dev/shm/looking-glass

echo "Starting Virtual Machine \"win10\""

sudo virsh start win10

count=0
minute=$(date +%M)

# If it restars more than 5 times in a minute, exit.
while true; do
    if [ $(date +%M) != "$minute" ]; then
        count=0
        minute=$(date +%M)
    fi

    looking-glass-client win:fullScreen spice:alwaysShowCursor

    if [ $? -eq 0 ]; then
        count=0
    else
        count=$((count+1))
    fi

    if [ $count -ge 5 ]; then
        echo "Program restarted more than 5 times in a minute. Exiting..."
        exit 1
    fi

    sleep 2
done
 
