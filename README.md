# Zenon
Shell script to install a [ZNN Node] (https://zenon.network) on a Linux server running Ubuntu 16.04/18.04 or Debian 9.5/9.8/9.9. Use it on your own risk.

***
## Installation:
```
1) apt-get update && apt-get install git
If you are installing the Node for the first time: 
1.1) cd ~
2.1) git clone https://github.com/zenonnetwork/ZNN-Node-deployer.git
3.1) cd ZNN-Node-deployer

If you want to update an existing Node: 
2.1) cd ~
2.2) cd ZNN-Node-deployer
3.2) git reset --hard && git pull

4) chmod +x znn_spawn_node.sh
5) ./znn_spawn_node.sh

If you get any errors:
6) cd ~
7) rm -rf ZNN-Node-deployer
8) start again with step 1.1 and ignore steps 2.1, 2.2 and 3.2.
```
***

## Desktop wallet setup

After the Node is up and running, you need to configure the desktop wallet accordingly. Here are the steps for a GUI (Windows/MacOS/Linux) wallet:
1. Open the Zenon Desktop Wallet.
2. Go to Receiving Addresses and create a new address: **Node1**
3. Send exactly **5000** **ZNN** to **Node1**.
4. Wait for 6 confirmations.
5. Enable Pillars tab if it's hidden: **Settings > Options > Wallet > Show Pillars Tab**
6. Navigate to **Pillars tab** and click on **Get outputs** to get a list with all  **output TXs** and the corresponding **output IDs**.
7. Click on **Config Node** and fill in the following entries:
```
Alias; VPS IP:port; Node Privkey; Output TX; Output ID
```
* Alias: **Node1**
* VPS IP:port: **IP:35993**
* Node Privkey: **Press Autofill Privkey** or generate it manually from Debug Console using ```masternode genkey``` command
* Output TX & ID: **Press Autofill OutputTX** or select them manually from Debug Console using  ```masternode outputs``` command
8. Press OK and close the wallet. You can also double check masternode.conf from the wallet folder location.
9. Reopen the wallet and wait to fully sync. Navigate to Pillars tab, select your Node and right click "Start Alias".
10. Login into your VPS terminal and check if the Node is successfully running by issuing the following command:
```
/usr/local/bin/Zenon-cli masternode status
```

## Usage:
```
Zenon-cli mnsync status
Zenon-cli getinfo
Zenon-cli masternode status
```

Also, if you want to check/start/stop **Zenon**, run one of the following commands as **root**:

**Ubuntu 16.04/18.04 Debian 9.5/9.8/9.9**:
```
systemctl status Zenon #To check the service is running.
systemctl start Zenon #To start Zenon service.
systemctl stop Zenon #To stop Zenon service.
systemctl is-enabled Zenon #To check whetether Zenon service is enabled on boot or not.
```
***
