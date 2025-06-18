#!/bin/bash
stretch_os=false
buster_os=false
ubuntu_os=false
jessie_os=false
retropie=false
pizero=false
pi4=false
pi3=false
java_installed=false
install_succesful=false
PIXELCADE_PRESENT=false #did we do an upgrade and pixelcade was already there
auto_update=false
attractmode=false
black=`tput setaf 0`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
magenta=`tput setaf 5`
white=`tput setaf 7`
reset=`tput sgr0`
upgrade_artwork=false
upgrade_software=false
version=11  #increment this as the script is updated
es_minimum_version=2.11.0
es_version=default
NEWLINE=$'\n'
pixelcadePort="/dev/ttyACM0"

cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

echo "       Pixelcade LED for Linux : Installer Version $version    "
echo ""
echo "This script will install Pixelcade LED software in $HOME/pixelcade"
echo "Pi 3 and Pi 4 family of devices are supported"
echo "Plese ensure you have at least 800 MB of free disk space in $HOME"
echo "Now connect Pixelcade to a free USB port on your device"
echo "Ensure the toggle switch on the Pixelcade board is pointing towards USB and not BT"
echo "Grab a coffee or tea as this installer will take between 10 and 20 minutes"

#INSTALLPATH="/home/pi/"
INSTALLPATH=$HOME"/"

# let's see what installation we have
if lsb_release -a | grep -q 'stretch'; then
        echo "${yellow}Linux Stretch Detected${white}"
        stretch_os=true
        echo "Installing curl..."
        sudo apt install -y curl
elif cat /etc/os-release | grep -q 'stretch'; then
       echo "${yellow}Linux Stretch Detected${white}"
       stretch_os=true
       echo "Installing curl..."
       sudo apt install -y curl
elif cat /etc/os-release | grep -q 'jessie'; then
      echo "${yellow}Linux Jessie Detected${white}"
      jessie_os=true
      echo "Installing curl..."
      sudo apt install -y curl
elif lsb_release -a | grep -q 'buster'; then
      echo "${yellow}Linux Buster Detected${white}"
      buster_os=true
      echo "Installing curl..."
      sudo apt install -y curl
elif cat /etc/os-release | grep -q 'buster'; then
      echo "${yellow}Linux Buster Detected${white}"
      buster_os=true
      echo "Installing curl..."
      sudo apt install -y curl
elif lsb_release -a | grep -q 'ubuntu'; then
      echo "${yellow}Ubuntu Linux Detected${white}"
      ubuntu_os=true
      echo "Installing curl..."
      sudo apt install -y curl
fi

#******************* MAIN SCRIPT START ******************************
# let's detect if Pixelcade is USB connected, could be 0 or 1 so we need to check both

if ! command -v lsusb  &> /dev/null; then
    echo "${red}lsusb command not be found so cannot check if Pixelcade is USB connected${white}"
else
   if lsusb | grep -q '1b4f:0008'; then
      echo "${yellow}Pixelcade LED Marquee Detected${white}"
   elif lsusb | grep -q '2e8a:1050'; then 
      echo "${yellow}Pixelcade LED Marquee Detected${white}"
   else  
      echo "${red}Sorry, Pixelcade LED Marquee was not detected, pleasse ensure Pixelcade is USB connected to your Pi and the toggle switch on the Pixelcade board is pointing towards USB, exiting...${white}"
      exit 1
   fi
fi

echo "${yellow}Stopping Pixelcade (if running...)${white}"
killall java #need to stop pixelweb.jar if already running
curl localhost:8080/quit

# The possible platforms are:
# linux_arm64
# linux_386
# linux_amd64
# linux_arm_v6
# linux_arm_v7
# linux_arm_v7pi temp hack for RetroPie

#rcade is armv7 userspace and aarch64 kernel space so it shows aarch64
#Pi model B+ armv6, no work

if uname -m | grep -q 'armv6'; then
   echo "${yellow}arm_v6 Detected..."
   machine_arch=arm_v6
fi

if uname -m | grep -q 'armv7'; then
   echo "${yellow}arm_v7 Detected..."
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch32'; then
   echo "${yellow}aarch32 Detected..."
   aarch32=arm_v7
fi

if uname -m | grep -q 'aarch64'; then
   echo "${yellow}aarch64 Detected..."
   machine_arch=arm64
fi

if uname -m | grep -q 'x86'; then
   echo "${yellow}x86 32-bit Detected..."
   machine_arch=386
fi

if uname -m | grep -q 'amd64'; then
   echo "${yellow}x86 64-bit Detected..."
   machine_arch=amd64
fi

if uname -m | grep -q 'x86_64'; then
   echo "${yellow}x86 64-bit Detected..."
   machine_arch=amd64
fi

if cat /proc/device-tree/model | grep -q 'Raspberry Pi 3'; then
   echo "${yellow}Raspberry Pi 3 detected..."
   pi3=true
fi

if cat /proc/device-tree/model | grep -q 'Pi 4'; then #this counts Pi 400 too
   printf "${yellow}Raspberry Pi 4 detected...\n"
   pi4=true
   #machine_arch=arm64
fi

if cat /proc/device-tree/model | grep -q 'Pi Zero W'; then
   printf "${yellow}Raspberry Pi Zero detected...\n"
   pizero=true
fi

if cat /proc/device-tree/model | grep -q 'ODROID-N2'; then
   printf "${yellow}ODroid N2 or N2+ detected...\n"
   odroidn2=true
fi

if [[ $machine_arch == "default" ]]; then
  echo "[ERROR] Your device platform WAS NOT Detected"
  echo "[WARNING] Guessing that you are on aarch64 but be aware Pixelcade may not work"
  machine_arch=arm64
fi

if [[ ! -d "${INSTALLPATH}pixelcade" ]]; then #create the pixelcade folder if it's not there
   mkdir ${INSTALLPATH}pixelcade
fi

#java needed for high scores, hi2txt
cd ${INSTALLPATH}pixelcade
JDKDEST="${INSTALLPATH}pixelcade/jdk"

if [[ ! -d $JDKDEST ]]; then #does Java exist already
    if [[ $machine_arch == "arm64" ]]; then
          echo "${yellow}Installing Java JRE 11 64-Bit for aarch64...${white}" #these will unzip and create the jdk folder
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-aarch64.zip #this is a 64-bit small JRE , same one used on the ALU
          unzip jdk-aarch64.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    elif [ $machine_arch == "arm_v7" ]; then
          echo "${yellow}Installing Java JRE 11 32-Bit for aarch32...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-aarch32.zip
          unzip jdk-aarch32.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    elif [ $machine_arch == "386" ]; then #pi zero is arm6 and cannot run the normal java :-( so have to get this special one
          echo "${yellow}Installing Java JRE 11 32-Bit for X86...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-x86-32.zip
          unzip jdk-x86-32.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    elif [ $machine_arch == "amd64" ]; then #pi zero is arm6 and cannot run the normal java :-( so have to get this special one
          echo "${yellow}Installing Java JRE 11 64-Bit for X86...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-x86-64.zip
          unzip jdk-x86-64.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    else
      echo "${red}Sorry, do not have a Java JDK for your platform, you'll need to install a Java JDK or JRE manually under /userdata/system/jdk"
    fi

    #now let's add java to path
    if cat ~/.bashrc | grep -q 'pixelcade/jdk/bin/java'; then
      echo "${yellow}Java already added to .bashrc, skipping...${white}"
    else
      echo "${yellow}Adding Java to Path via .bashrc (Java is needed for high scores)...${white}"
      sed -i -e '$aexport PATH="$HOME/pixelcade/jdk/bin:$PATH"' ~/.bashrc
    fi

fi

if [[ -f master.zip ]]; then
    rm master.zip
fi

cd ${INSTALLPATH}pixelcade
wget -O ${INSTALLPATH}pixelcade/pixelweb https://github.com/alinke/pixelcade-linux-builds/raw/main/linux_${machine_arch}/pixelweb
chmod +x pixelweb
./pixelweb -install-artwork #install the artwork

if [[ $? == 2 ]]; then #this means artwork is already installed so let's check for updates and get if so
  echo "Checking for new Pixelcade artwork..."
  cd ${INSTALLPATH}pixelcade && ./pixelweb -update-artwork
fi

if [[ -d ${INSTALLPATH}ptemp ]]; then
    rm -r ${INSTALLPATH}ptemp
fi

mkdir ${INSTALLPATH}ptemp
cd ${INSTALLPATH}ptemp
if [[ -d ${INSTALLPATH}ptemp/pixelcade-linux-main ]]; then #remove this folder if it's already there
    sudo rm -r ${INSTALLPATH}ptemp/pixelcade-linux-main
fi

echo "${yellow}Installing Pixelcade System Files...${white}"
#get the Pixelcade system files
wget -O ${INSTALLPATH}ptemp/main.zip https://github.com/alinke/pixelcade-linux/archive/refs/heads/main.zip
unzip main.zip

sed -i '/all,mame/d' ${INSTALLPATH}pixelcade/console.csv
sed -i '/favorites,mame/d' ${INSTALLPATH}pixelcade/console.csv
sed -i '/recent,mame/d' ${INSTALLPATH}pixelcade/console.csv

echo "${yellow}Installing Fonts...${white}"
cd ${INSTALLPATH}pixelcade
mkdir ${INSTALLPATH}.fonts
sudo cp ${INSTALLPATH}pixelcade/fonts/*.ttf ${INSTALLPATH}.fonts
sudo apt -y install font-manager
sudo fc-cache -v -f

echo "${yellow}Adding Pixelcade to Startup via pixelcade.service...${white}"
cd ${INSTALLPATH}pixelcade/system && rm autostart.sh && rm pixelcade.service
wget -O ${INSTALLPATH}pixelcade/system/autostart.sh https://raw.githubusercontent.com/MontesDesigns/pixelcade-linux-builds/refs/heads/main/system/autostart.sh
wget -O ${INSTALLPATH}pixelcade/system/pixelcade.service https://raw.githubusercontent.com/MontesDesigns/pixelcade-linux-builds/refs/heads/main/system/pixelcade.service
sudo chmod +x ${INSTALLPATH}pixelcade/system/autostart.sh # TO DO need to replace this
sudo cp ${INSTALLPATH}pixelcade/system/pixelcade.service /etc/systemd/system/pixelcade.service

#to do add check if the service is already running
sudo systemctl start pixelcade.service
sudo systemctl enable pixelcade.service

sudo chown -R pi: ${INSTALLPATH}pixelcade #this is our fail safe in case the user did a sudo ./setup.sh which seems to be needed on some pre-made Pi images

if [[ -d "/etc/udev/rules.d" ]]; then #let's create the udev rule for Pixelcade if the rules.d folder is there
  echo "${yellow}Adding udev rule...${white}"
  sudo wget -O /etc/udev/rules.d/99-pixelcade.rules https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/install-scripts/99-pixelcade.rules
  sudo /etc/init.d/udev restart #BUT it seems this takes a re-start and does not work immediately
fi

#cd ~/pixelcade && ./pixelweb -d "${pixelcadePort}"  -image "system/pixelcade.png" -startup &
cd ~/pixelcade && ./pixelweb -image "system/pixelcade.png" -startup &

echo "Cleaning Up..."
cd ${INSTALLPATH}

if [[ -f master.zip ]]; then
    rm master.zip
fi

rm ${SCRIPTPATH}setup-pandorydx.sh

if [[ -d ${INSTALLPATH}ptemp ]]; then
    rm -r ${INSTALLPATH}ptemp
fi

echo ""
pixelcade_version="$(cd ${INSTALLPATH}pixelcade && ./pixelweb -version)"
echo "[INFO] $pixelcade_version Installed"
install_succesful=true

echo "Pausing for 5 seconds..."
sleep 5

echo " "
echo "[INFO] An LED art pack is available at https://pixelcade.org/artpack/"
echo "[INFO] The LED art pack adds additional animated marquees for select games"
echo "[INFO] After purchase, you'll receive a serial code and then install with this command:"
echo "[INFO] cd ~/pixelcade && ./pixelweb --install-artpack <serial code>"
echo "INSTALLATION COMPLETE , please reboot when you can"