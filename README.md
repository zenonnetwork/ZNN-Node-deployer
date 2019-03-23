# Zenon
Shell script to install a [ZNN Node] (https://zenon.network) on a Linux server running Ubuntu 14.04/16.04/18.04 or Debian 9.5/9.8. Use it on your own risk.

***
## Installation:
```
1) wget -q https://github.com/zenonnetwork/ZNN-Node-deployer/blob/master/znn_spawn_node.sh
2) bash znn_spawn_node.sh
```
***

## Desktop wallet setup

After the Node is up and running, you need to configure the desktop wallet accordingly. Here are the steps for a GUI (Windows/MacOS) wallet:
1. Open the Zenon Desktop Wallet.
2. Go to RECEIVE and create a New Address: **Node1**
3. Send **5000** **ZNN** to **Node1**.
4. Wait for 6 confirmations.
5. Go to **Tools -> "Debug console - Console"**
6. Type the following command: **masternode outputs**
7. Go to  ** Tools -> "Open Node Configuration File"
8. Add the following entry:
```
Alias Address Privkey TxHash Output_index
```
* Alias: **Node1**
* Address: **VPS_IP:PORT**
* Privkey: **Masternode Private Key**
* TxHash: **First value from Step 6**
* Output index:  **Second value from Step 6**
9. Save and close the file.
10. Go to **Pillars Tab**. If you tab is not shown, please enable it from: **Settings - Options - Wallet - Show Pillars Tab**
11. Click **Update status** to see your node. If it is not shown, close the wallet and start it again. Make sure the wallet is unlocked & fully sync'ed.
12. Open **Debug Console** and type:
```
startmasternode "alias" "0" "Node1"
```
***

## Usage:
```
Zenon-cli mnsync status
Zenon-cli getinfo
Zenon-cli masternode status
```

Also, if you want to check/start/stop **Zenon** , run one of the following commands as **root**:

**Ubuntu 16.04/18.04 Debian 9.5/9.8**:
```
systemctl status Zenon #To check the service is running.
systemctl start Zenon #To start Zenon service.
systemctl stop Zenon #To stop Zenon service.
systemctl is-enabled Zenon #To check whetether Zenon service is enabled on boot or not.
```
**Ubuntu 14.04**:  
```
/etc/init.d/Zenon start #To start Zenon service
/etc/init.d/Zenon stop #To stop Zenon service
/etc/init.d/Zenon restart #To restart Zenon service
```

***
