#!/bin/bash

TMP_FOLDER=$(mktemp -d)
TMP_FILE=$(mktemp)
CONFIG_FILE='Zenon.conf'
CONFIGFOLDER='/root/.Zenon'
COIN_DAEMON='/usr/local/bin/Zenond'
COIN_CLI='/usr/local/bin/Zenon-cli'
COIN_REPO='https://zenon.network/download/zenon-linux64.zip'
COIN_NAME='Zenon'
COIN_PORT=35993


NODEIP=$(curl -s4 api.ipify.org)


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


function download_node() {
  echo -e "\n"
  echo -e "-----------------------------------------------------------------------------------------------"
  cd $TMP_FOLDER
echo -e "Downloading ${GREEN}$COIN_NAME${NC}. Please wait"
  wget -q $COIN_REPO
  COIN_ZIP=$(echo $COIN_REPO | awk -F'/' '{print $NF}')
  echo -e "Verifying SHA256 checksum"
  echo "2a3dc355924ec28ca25cf1ad98442b6fad1dd4ba3b1404a9358b938f2fa95f14 $COIN_ZIP" | sha256sum -c || exit 1
  unzip $COIN_ZIP >/dev/null 2>&1
  cp $COIN_NAME* /usr/local/bin
  chmod +x /usr/local/bin/Zenon*
  rm -rf $TMP_FOLDER >/dev/null 2>&1
}


function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target
[Service]
User=root
Group=root
Type=forking
#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid
ExecStart=$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

  sleep 1
  echo -e "Reloading ${RED}$systemd${NC} daemon"
  systemctl daemon-reload
  sleep 5
  echo -e "Starting ${GREEN}$COIN_NAME${NC} daemon"
  systemctl start $COIN_NAME.service
  sleep 1
  echo -e "Enabling ${GREEN}$COIN_NAME${NC} service"
  systemctl enable $COIN_NAME.service >/dev/null 2>&1

  if ! pgrep -x Zenond; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
addnode=seed.zenon.network
addnode=seed.zenon.exchange
addnode=seed-1.zenon.exchange
addnode=seed.znn.space
addnode=seed-1.znn.space
addnode=seed.zenon.foundation
addnode=seed.zenon.one
addnode=seed.znn.one
addnode=alpha-1.zenon.network
addnode=alpha-2.zenon.foundation
addnode=alpha-3.zenon.one
addnode=alpha-4.znn.one
addnode=alpha-5.znn.space
EOF
}

function create_key() {
  echo -e "-----------------------------------------------------------------------------------------------"
  echo -e "Enter your ${GREEN}$COIN_NAME $(cat $TMP_FILE) Private Key${NC} generated in the wallet with ${GREEN}createmasternodekey${NC} command. Leave it blank to generate a new ${GREEN}$COIN_NAME $(cat $TMP_FILE) Private Key${NC} for you and paste it into the ${GREEN}masternode.conf${NC} file from the controller wallet's config directory:"
  read -e COINKEY
  if [[ -z "$COINKEY" ]]; then 
  $COIN_DAEMON -daemon
  sleep 30
  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
   echo -e "${RED}$COIN_NAME server couldn't start.{$NC} Check /var/log/syslog for errors"
   exit 1
  fi
  COINKEY=$($COIN_CLI createmasternodekey)
  if [ "$?" -gt "0" ];
    then
    echo -e "${RED}Wallet not fully loaded.${NC} Please wait"
    sleep 30
    COINKEY=$($COIN_CLI createmasternodekey)
  fi
  $COIN_CLI stop
fi
}

function update_config() {
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
logtimestamps=1
maxconnections=256
bind=$NODEIP
masternode=1
externalip=$NODEIP
externalip=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
EOF
}


function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$COIN_PORT${NC}"
  ufw allow $COIN_PORT/tcp >/dev/null 2>&1
  ufw allow ssh >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}



function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 api.ipify.org))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}

function detect_ubuntu() {
 echo -e "Detecting Linux distribution"
 linux_distro=$(lsb_release -d)
 if [[  $linux_distro == *16.04* ]]; then
   UBUNTU_VERSION=16
 elif [[ $linux_distro == *18.04* ]]; then
   UBUNTU_VERSION=18
 elif [[ $linux_distro == *9.5* ]]; then
   DEBIAN_VERSION=9.5
 elif [[ $linux_distro == *9.6* ]]; then
   DEBIAN_VERSION=9.6
 elif [[ $linux_distro == *9.7* ]]; then
   DEBIAN_VERSION=9.7
 elif [[ $linux_distro == *9.8* ]]; then
   DEBIAN_VERSION=9.8
 elif [[ $linux_distro == *9.9* ]]; then
    DEBIAN_VERSION=9.9
 elif [[ $linux_distro == *9.10* ]]; then
    DEBIAN_VERSION=9.10
 elif [[ $linux_distro == *9.11* ]]; then
    DEBIAN_VERSION=9.11
 else
   echo -e "${RED}You are not running Ubuntu 16.04 / 18.04 or Debian 9.5 - 9.11 \nInstallation is cancelled${NC}"
   exit 1
 fi
 echo $linux_distro
}


function checks() {
 detect_ubuntu
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi
    echo -e "Finishing checks"
}


function prepare_system() {
	echo -e "-----------------------------------------------------------------------------------------------"
	echo -e "Preparing the system for ${GREEN}$COIN_NAME deployer${NC}. Installing additional packages. Please wait"
	apt-get update >/dev/null 2>&1
	apt-get install systemd unzip net-tools wget ufw sudo curl pkg-config jq -y
	if [[ ! -f $COIN_DAEMON && -x $COIN_DAEMON ]]; then
		chmod +x $COIN_DAEMON
	fi
	if [[ ! -f $COIN_CLI && -x $COIN_CLI ]]; then
		chmod +x $COIN_CLI
	fi
}


function important_information() {
 echo -e "$COIN_NAME $(cat $TMP_FILE) is up and running listening on port ${RED}$COIN_PORT${NC}"
 echo -e "Configuration file: ${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $COIN_NAME.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $COIN_NAME.service${NC}"
 echo -e "VPS IP and port: ${RED}$NODEIP:$COIN_PORT${NC}"
 echo -e "$(cat $TMP_FILE) private key: ${RED}$COINKEY${NC}"
 if [[ -n $SENTINEL_REPO  ]]; then
  echo -e "${RED}Sentinel${NC} is installed in ${RED}$CONFIGFOLDER/sentinel${NC}"
  echo -e "Sentinel logs is: ${RED}$CONFIGFOLDER/sentinel.log${NC}"
 fi
 echo -e "Check if $COIN_NAME $(cat $TMP_FILE) is running by using the following command: ${RED}ps -ef | grep $COIN_DAEMON | grep -v grep${NC}"
 echo -e "-----------------------------------------------------------------------------------------------"
}

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  configure_systemd
}

function node_type_selection () {
  echo -e "Press 1 to setup a ${GREEN}Pillar${NC}"
  echo -e "Press 2 to setup a ${GREEN}Node${NC}"
  echo -e "Press X to ${RED}exit${NC} the setup"
  read -n 1 -p "Input Selection: " node_type_selection
  if [ "$node_type_selection" = "1" ]; then
			echo "Pillar" > "$TMP_FILE"
        elif [ "$node_type_selection" = "2" ]; then
            echo "Node" > "$TMP_FILE"
        elif [ "$node_type_selection" = "X" ];then
			clear
            exit 1
        else
			echo -e "   "
            echo -e "You have entered an invalid selection. Please retry."
            echo -e "Press any key to continue..."
			echo -e "   "
            read -n 1
            clear
            node_type_selection
        fi
}

##### Main #####
clear

echo -e "

 __________ _   _  ___  _   _
|__  / ____| \ | |/ _ \| \ | |
  / /|  _| |  \| | | | |  \| |
 / /_| |___| |\  | |_| | |\  |
/____|_____|_| \_|\___/|_| \_|


"
checks
prepare_system
if [[ -d "$CONFIGFOLDER" ]]; then
    if [[ -e "$COIN_DAEMON" ]]; then
        version=$($COIN_DAEMON -version | grep version)
        read -p "$version is currently installed. Do you want to continue with the updating process? (Y/n)? " CONT
    else
        read -p "$COIN_NAME datadir folder found on system. Do you want to continue with the updating process? (Y/n)? " CONT
    fi
    if [ "$CONT" != "n" ]; then
            echo -e "Preparing to ${RED}disable${NC} ${GREEN}$COIN_NAME${NC} service"
            systemctl disable $COIN_NAME.service >/dev/null 2>&1
            sleep 10
            echo -e "Preparing to ${RED}stop${NC} ${GREEN}$COIN_NAME${NC} service"
            systemctl stop $COIN_NAME.service >/dev/null 2>&1
            $COIN_CLI stop >/dev/null 2>&1
            sleep 10
            echo -e "Preparing to ${RED}delete${NC} old ${GREEN}$COIN_NAME${NC} version"
            rm -rf /usr/local/bin/$COIN_NAME*
            echo -e "Preparing to download new ${GREEN}$COIN_NAME${NC} version"
            download_node
            sleep 1
            $COIN_DAEMON -resync -daemon
            new_version=$($COIN_DAEMON -version | grep version)
            sleep 5
            echo -e "Preparing to re-enable $COIN_NAME service"
            systemctl enable $COIN_NAME.service >/dev/null 2>&1
            echo -e "Updated successfully to $new_version. Wait for a ${GREEN}full sync${NC}. After that you can restart it from ${GREEN}Pillars${NC} tab from the wallet"
    else
        exit
    fi
else
    echo -e "Preparing to install ${GREEN}$COIN_NAME${NC}"
    node_type_selection
    download_node
    setup_node
    sleep 3
    if ! pgrep -x Zenond; then
        echo -e "$COIN_NAME $(cat $TMP_FILE) not running, restarting daemon"
        $COIN_DAEMON -resync -daemon
    fi
    echo -e "Setup finished successfully. Wait for the $(cat $TMP_FILE) to ${GREEN}fully sync${NC}. After that you can start it from ${GREEN}Pillars${NC} tab from the wallet"
    if [[ -e "$TMP_FILE" ]]; then
        rm $TMP_FILE >/dev/null 2>&1
    fi
fi
