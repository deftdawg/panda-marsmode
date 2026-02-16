#!/usr/bin/env bash

# REPO_URL="https://github.com/spleck/panda.git"
REPO_URL="https://github.com/deftdawg/panda-marsmode.git"

sudo apt install -y 
sudo nala install -y byobu build-essential 
# python git
sudo nala clean
# pip install --upgrade setuptools
# curl -s https://raw.githubusercontent.com/spleck/panda/master/examples/marsmode/marsmode-install.sh | bash

#
# panda auto setup script for mars mode on PiOS
#
# will install requirements, build custom firmware, flash panda, and setup boot script

echo '----------------------------------------------------------------------'
echo ' '
echo '                   ** MarsMode install for PiOS! **'
echo ' '
echo '----------------------------------------------------------------------'

BIND=`dirname $0`

# verbose flag
# if [ "q$V" == "q" ]; then
#       V=0
# fi
V=1
PYTHON=$(type -p python3 python)
# check for PiOS
echo -n "Checking for approved distro... "
if [ -f '/etc/apt/sources.list.d/raspi.list' ]
then
        echo "OK"
else
        echo "OOPS"
        echo "- This installer has only been tested for use ONLY with PiOS."
        echo -n "- *** Proceed anyway? [y/N] "
        read piosOverride
        if [ "q$piosOverride" == "qy" ]
        then
                echo '- Proceeding with OVERRIDE. Good luck!'
        else
                echo '- Aborted due to unfamiliar territory. Try again with PiOS.'
                exit -1
        fi
fi

# install dependencies
# echo -n "Installing system dependencies... "
# if [ $V == 1 ]; then
#       echo " "; echo " "
#       sudo apt-get update
#       sudo nala install -y dfu-util gcc-arm-none-eabi python3-pip python3-venv libffi-dev git scons screen
# else
#       sudo apt-get update >/dev/null 2>&1
#       sudo nala install -y dfu-util gcc-arm-none-eabi python3-pip python3-venv libffi-dev git scons screen 2>&1
#       sleep 1 && echo "OK" && sleep 1
# fi

# grab the git checkout
echo -n "Checking out spleck panda git repo... "
if [ -d "panda/.git" ]; then
        echo " SKIPPED"
else
        if [ $V == 1 ]; then
                echo " "; echo " "
                git clone ${REPO_URL} ~/panda
                python3 -m venv ~/panda/
        else
                git clone ${REPO_URL} ~/panda >/dev/null 2>&1
                python3 -m venv ~/panda/ >/dev/null 2>&1
                sleep 1 && echo "OK" && sleep 1
        fi
fi

# python local env
echo -n "Setting up local python env... "
if [ -f "panda/bin/python3" ]; then
        echo " SKIPPED"
else
        if [ $V == 1 ]; then
                echo " "; echo " "
                python3 -m venv ~/panda/
        else
                python3 -m venv ~/panda/ >/dev/null 2>&1
                sleep 1 && echo "OK" && sleep 1
        fi
fi


export PATH=~/panda/bin:$PATH
cd panda

# install requirements
echo -n "Installed app dependencies... "
if [ $V == 1 ]; then
        echo " "; echo " "
        pip install -r requirements.txt
        python3 setup.py install
else
        pip install -r requirements.txt >/dev/null 2>&1
        python3 setup.py install >/dev/null 2>&1
        sleep 1 && echo "OK" && sleep 1
fi

# check for / setup udev rules
echo -n "Checking udev configuration... "
if [ -f /etc/udev/rules.d/11-panda.rules ]; then
        echo "SKIPPED"
else
        sudo tee /etc/udev/rules.d/11-panda.rules <<EOF >/dev/null
SUBSYSTEM=="usb", ATTRS{idVendor}=="bbaa", ATTRS{idProduct}=="ddcc", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="bbaa", ATTRS{idProduct}=="ddee", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0666"
EOF
        sudo udevadm control --reload-rules && sudo udevadm trigger
        sleep 1 && echo "OK" && sleep 1
fi

# build custom panda firmware
cd board
echo -n "Building firmware... "
if [ $V == 1 ]; then
        echo " "; echo " "
        scons -u
else
        scons -u >/dev/null 2>&1
        sleep 1 && echo "OK" && sleep 1
fi

# symlink hotfix for flashing
for dir in ~/panda/lib/python*/site-packages/pandacan*; do ln -s ~/panda/board $dir/board; done

echo -n "Recovery mode panda... "
echo " "; echo " "
./recover.py
if [ $? -ne 0 ]; then
        echo "*** RECOVERY MODE ERROR *** exit code $?"
        exit -1
fi
echo " "; echo " "

echo -n "Flashing panda... "
echo " "; echo " "
./flash.py
if [ $? -ne 0 ]; then
        echo "*** FLASH ERROR *** exit code $?"
        exit -1
fi
echo " "; echo " "

# add rc.local execution if not present
echo -n 'Checking rc.local for startup... '
cnt=`grep marsmode /etc/rc.local | wc -l`
if [ $cnt -gt 0 ]; then
        echo "SKIPPED"
else
        echo "adding startup to rc.local"
        grep -v ^exit /etc/rc.local >/tmp/.rcl
        echo screen -d -m -S mars /home/$USER/panda/examples/marsmode/marsmode-active.sh >>/tmp/.rcl
        echo exit 0 >>/tmp/.rcl
        if [ $V == 1 ]; then
                echo " "; echo " "
                cat /tmp/.rcl | sudo tee /etc/rc.local
        else
                cat /tmp/.rcl | sudo tee /etc/rc.local >/dev/null
                sleep 1 && echo OK && sleep 1
        fi
fi

# run marsmode-active.sh to link default active script
echo -n 'Setting default MarsMode script to marsmode-mediavolume-basic... '
if [ $V == 1 ]; then
        echo " "; echo " "
        ~/panda/examples/marsmode/marsmode-active.sh ~/panda/examples/marsmode/marsmode-mediavolume-basic.py
else
        ~/panda/examples/marsmode/marsmode-active.sh ~/panda/examples/marsmode/marsmode-mediavolume-basic.py >/dev/null
        sleep 1 && echo OK && sleep 1
fi

# add boot config to enable single cable for power+data for pi4
if [ -f /boot/firmware/config.txt ]; then
        cnt=`grep dr_mode=host /boot/firmware/config.txt | wc -l`
        if [ $cnt -eq 0 ]; then
                echo dtoverlay=dwc2,dr_mode=host | sudo tee -a /boot/firmware/config.txt >/dev/null
        fi
fi

# done
echo ' '
echo '----------------------------------------------------------------------'
echo ' '
echo '        ** MarsMode install complete. Ready to GO! **'
echo ' '
echo "  To adjust startup script: cd ~/panda/examples/marsmode/ and run ./marsmode-active.sh <script>"
echo ' ' && sleep 1
