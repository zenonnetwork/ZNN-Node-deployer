# Zenon
Shell script to install a [ZNN Node] (https://zenon.network) on a Linux server running Ubuntu 18.04 or Debian 9.5 - 9.9. Use it on your own risk.

***
## How to run the script:
```
1) wget -q https://raw.githubusercontent.com/zenonnetwork/ZNN-Node-deployer/master/znn_spawn_node.sh
2) chmod +x znn_spawn_node.sh && ./znn_spawn_node.sh
```
***

## Desktop wallet setup

After the Node/Pillar is up and running, you need to configure the desktop wallet accordingly. Here are the steps for a GUI (Windows/MacOS/Linux) wallet:
1. Open the Zenon Desktop Wallet
2. Go to Receiving Addresses and create a new address: **Node1** or **Pillar1**
3. Send exactly **5000 ZNN** to **Node1** or **15000 ZNN** to **Pillar1**
4. Wait for 6 confirmations
5. Enable the Pillars tab if it's hidden: **Settings > Options > Wallet > Show Pillars Tab**
6. Navigate to **Pillars tab** and click on **Get Node/Pillar outputs** to get a list with all  **output TXs** and the corresponding **output IDs**.
7. Click on **Config Node** and fill in the following entries:
```
Alias; VPS IP:port; Node/Pillar Privkey; Output TX; Output ID
```
* Alias: **Node1** or **Pillar1**
* VPS IP:port: **IP:35993**
* Node/Pillar Privkey: **Press Autofill Privkey** or generate it manually from Debug Console using ```createmasternodekey``` command
* Output TX & ID: **Press Autofill OutputTX** or select them manually from Debug Console using  ```getmasternodeoutputs``` or ```getpillaroutputs```command
8. Press OK and close the wallet. You can also double check masternode.conf: **Tools > Open Node Configuration file**
9. Reopen the wallet and wait to fully sync. Navigate to Pillars tab, select your Node/Pillar and click "Start Alias"
10. Login into your VPS terminal and check if the Node/Pillar is successfully running by issuing the following command:
```
/usr/local/bin/Zenon-cli getmasternodestatus 		#For Node
/usr/local/bin/Zenon-cli getpillarstatus 		#For Pillar
```

## Usage:
```
/usr/local/bin/Zenon-cli getstakingstatus			#Wait for mnsync = true before starting it from the wallet
/usr/local/bin/Zenon-cli getmasternodestatus			#For Node
/usr/local/bin/Zenon-cli getpillarstatus			#For Pillar
```

Also, if you want to check/start/stop **Zenon**, run one of the following commands as **root**:
```
systemctl status Zenon			#To check the service is running
systemctl start Zenon			#To start Zenon service
systemctl stop Zenon			#To stop Zenon service
systemctl is-enabled Zenon			#To check whetether Zenon service is enabled on boot or not
```
