#!/bin/bash

TMP_FOLDER=$(mktemp -d)
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

function compile_node() {
  echo -e "-----------------------------------------------------------------------------------------------"
  echo -e "Prepare to download $COIN_NAME"
  cd $TMP_FOLDER
  wget -q $COIN_REPO
  compile_error
  COIN_ZIP=$(echo $COIN_REPO | awk -F'/' '{print $NF}')
  unzip $COIN_ZIP >/dev/null 2>&1
  cd zenon-linux64
  compile_error
  cp Zenon* /usr/local/bin
  chmod 777 $COIN_DAEMON
  chmod 777 $COIN_CLI
  compile_error
  #strip $COIN_DAEMON $COIN_CLI
  cd -
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
ExecStop=-$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

  echo -e "Reloading daemon"
  systemctl daemon-reload
  sleep 5
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1

  if [[ -n "$(pgrep -x $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function configure_startup() {
  cat << EOF > /etc/init.d/$COIN_NAME
#! /bin/bash
### BEGIN INIT INFO
# Provides: $COIN_NAME
# Required-Start: $remote_fs $syslog
# Required-Stop: $remote_fs $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: $COIN_NAME
# Description: This file starts and stops $COIN_NAME MN server
#
### END INIT INFO
case "\$1" in
 start)
   $COIN_DAEMON -daemon
   sleep 5
   ;;
 stop)
   $COIN_CLI stop
   ;;
 restart)
   $COIN_CLI stop
   sleep 10
   $COIN_DAEMON -daemon
   ;;
 *)
   echo "Usage: $COIN_NAME {start|stop|restart}" >&2
   exit 3
   ;;
esac
EOF
chmod +x /etc/init.d/$COIN_NAME >/dev/null 2>&1
update-rc.d $COIN_NAME defaults >/dev/null 2>&1
/etc/init.d/$COIN_NAME start >/dev/null 2>&1
if [ "$?" -gt "0" ]; then
 sleep 5
 /etc/init.d/$COIN_NAME start >/dev/null 2>&1
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
port=$COIN_PORT
EOF
}

function create_key() {
  echo -e "-----------------------------------------------------------------------------------------------"
  echo -e "Enter your ${RED}$COIN_NAME Node Private Key${NC} generated in the wallet with masternode genkey command. Leave it blank to generate a new ${RED}$COIN_NAME Node Private Key${NC} for you:"
  read -e COINKEY
  if [[ -z "$COINKEY" ]]; then 
  $COIN_DAEMON -daemon
  sleep 30
  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
   echo -e "${RED}$COIN_NAME server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  COINKEY=$($COIN_CLI masternode genkey)
  if [ "$?" -gt "0" ];
    then
    echo -e "${RED}Wallet not fully loaded. Wait and try again to generate the Private Key${NC}"
    sleep 30
    COINKEY=$($COIN_CLI masternode genkey)
  fi
  $COIN_CLI stop
fi
}

function update_config() {
  #sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
logtimestamps=1
maxconnections=256
bind=$NODEIP
masternode=1
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


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $COIN_NAME. Please investigate.${NC}"
  exit 1
fi
}

function detect_ubuntu() {
   echo -e "Detecting Linux distribution"
 if [[ $(lsb_release -d) == *16.04* ]]; then
   UBUNTU_VERSION=16
 elif [[ $(lsb_release -d) == *14.04* ]]; then
   UBUNTU_VERSION=14
 elif [[ $(lsb_release -d) == *18.04* ]]; then
   UBUNTU_VERSION=18
 elif [[ $(lsb_release -d) == *9.5* ]]; then
   DEBIAN_VERSION=9.5
 elif [[ $(lsb_release -d) == *9.8* ]]; then
   DEBIAN_VERSION=9.8
else
   echo -e "${RED}You are not running Ubuntu 14.04 / 16.04 / 18.04 or Debian 9.5 / 9.8 Installation is cancelled.${NC}"
   exit 1
fi
echo $(lsb_release -d)
}


function checks() {
 detect_ubuntu
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMON" ] ; then
  echo -e "${RED}$COIN_NAME is already installed.${NC}"
  exit 1
fi
  echo -e "Finishing checks"
}

function prepare_system() {
	echo -e "-----------------------------------------------------------------------------------------------"
	echo -e "Prepare the system to install ${GREEN}$COIN_NAME${NC} node. Installing additional packages."
	apt-get update >/dev/null 2>&1
	apt-get install unzip net-tools wget ufw sudo curl pkg-config
	#DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
	#DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
	#apt install -y software-properties-common >/dev/null 2>&1
	#echo -e "${GREEN}Adding bitcoin PPA repository"
	#apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
	#echo -e "Installing required packages, it may take some time to finish.${NC}"
	#apt-get update >/dev/null 2>&1
	#apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
	#build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
	#libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
	#libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev>/dev/null 2>&1
	#if [ "$?" -gt "0" ];
	#  then
	#	echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
	#	echo "apt-get update"
	#	echo "apt -y install software-properties-common"
	#	echo "apt-add-repository -y ppa:bitcoin/bitcoin"
	#	echo "apt-get update"
	#	echo "apt install -y net-tools make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
	#libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
	#bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban pkg-config libevent-dev"
	# exit 1
	#fi
}


function important_information() {
 echo -e "$COIN_NAME Node is up and running listening on port ${RED}$COIN_PORT${NC}."
 echo -e "Configuration file is: ${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 if [[ $UBUNTU_VERSION == 14 ]]; then
   echo -e "Start: ${RED}/etc/init.d/$COIN_NAME start${NC}"
   echo -e "Stop: ${RED}/etc/init.d/$COIN_NAME stop${NC}"
 else
   echo -e "Start: ${RED}systemctl start $COIN_NAME.service${NC}"
   echo -e "Stop: ${RED}systemctl stop $COIN_NAME.service${NC}"
 fi
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$COIN_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$COINKEY${NC}"
 if [[ -n $SENTINEL_REPO  ]]; then
  echo -e "${RED}Sentinel${NC} is installed in ${RED}$CONFIGFOLDER/sentinel${NC}"
  echo -e "Sentinel logs is: ${RED}$CONFIGFOLDER/sentinel.log${NC}"
 fi
 echo -e "Check if $COIN_NAME is running by using the following command: ${RED}ps -ef | grep $COIN_DAEMON | grep -v grep${NC}"
 echo -e "-----------------------------------------------------------------------------------------------"
}

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  if [[ $UBUNTU_VERSION == 14 ]]; then
	configure_startup
  else
	configure_systemd
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
compile_node
setup_node
$COIN_DAEMON -daemon
echo -e "Setup finished successfully. Node ready for remote activation. Start the node from Pillars tab in the wallet."
