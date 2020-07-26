#!/bin/bash

clear

#-----------------------------------------------------------------------------------------
# User intent declaration
#-----------------------------------------------------------------------------------------
echo "This program will guide you through the interface setup for your Wireless Offload Concentrator"
echo "This operation will over-write all current WOC interfaces, it should only be run to install the WOC"
echo " or to correct any errors entered during a previous run of this script."

echo "do you want to proceed? (y/n)"

read proceed

if [[ $proceed != "y" ]]; then
	echo "setup canceled."
	exit
fi

clear

#-----------------------------------------------------------------------------------------
# User readme
#-----------------------------------------------------------------------------------------
echo "There are 2 primary interfaces associated with the WOC, the internal (ens224) interface"
echo "and the external (ens192) interface."
echo "The internal interface is an unnumbered ethernet interface that connects to the local LAN"
echo "every VLAN spanned to this interface from the connected switch will be forwarded to the WAG."
echo "It is therefore necessary for you to control the trunk interface on the switch to prevent" 
echo "unwanted traffic"
echo "from traversing the WOC."
echo "For example, on a Cisco switch the configuration would include the following:"
echo "---------------------------------------------"
echo "switchport mode trunk"
echo "switchport trunk allowed vlan 20,40,666"
echo "---------------------------------------------"
echo "This will ensure that only vlans 20, 40, and 666 have access to the WOC tunneling transport to the WAG." 
echo "you can of course add VLANs later as you see fit"
echo "by simply adding the vlan to the trunk interface on the switch."
echo "Press any key to continue..."
read anykey

echo "The external interface can be dual-stacked with IPv4 and IPv6 addressing, but for the purposes of tunneling,"
echo "only requires an IPv6 address.The IPv4 address given to this interface is used for the purposes of management"
echo "and reporting, and is optoinal - though highly recommended. Make sure that ens192 has an IPv4 address before running"
echo "this script."



#-----------------------------------------------------------------------------------------
# Collect external interface parameters, build dataplane interfaces
#-----------------------------------------------------------------------------------------
echo "Now lets begin to enter some informaion about the WOC"
echo "First, lets configure the external interface"

echo "please enter the IPv6 address you would like to assign to the external interface"
read localIPv6
echo "Please enter the IPv6 default gateway:"
read localIPv6Gateway

clear

echo "The following parameters will be applied to the external interface (ens192):"
echo "---------------------------------------------"
echo "ens192"
echo "IPv6 address "$localIPv6
echo "IPv6 gateway: "$localIPv6Gateway
echo "---------------------------------------------"

echo "Are these parameters correct? (y/n)"
read applyExtYn

if [[ $applyExtYn != "y" ]]; then
	echo "Parameters discarded, please re-run the script"
	exit
else

#-----------------------------------------------------------------------------------------
# rebuild local files and apply
#-----------------------------------------------------------------------------------------
	echo "Writing interface parameters"
	echo "IPV6ADDR="$localIPv6 >> /etc/sysconfig/network-scripts/ifcfg-ens192
	echo "IPV6_DEFAULTGW="$localIPv6Gateway >> /etc/sysconfig/network-scripts/ifcfg-ens192
	clear
	more ifcfg-ens192
fi

#-----------------------------------------------------------------------------------------
# Collect failover interface parameters
#-----------------------------------------------------------------------------------------
echo "The WOCs need 2 VLANs to monitor one another for the purposes of high-availability and failover,"
echo "these 2 VLANs should be spanned to both the internal and failover interfaces (ens224, ens256)"
echo "you must provide one VLAN per WOC, when you setup the partner WOC you will provide the other VLAN"
echo "Please provide the VLAN ID number for this WOC (just the number)"
read vlanID
echo "VLAN" $vlanID "will be used for the failover network, please ensure it is spanned to all WOC internal"
echo "(ens224) and failover (ens256) interfaces on both WOCs"

#-----------------------------------------------------------------------------------------
# build ens256
#-----------------------------------------------------------------------------------------
rm -rf ifcfg-ens256
cp ens256.woc ifcfg-ens256
echo DEVICE=ens256 >> ifcfg-ens256
cp ifcfg-ens256 /etc/sysconfig/network-scripts/
echo "---------------------------------------------"
echo "Internal interface (ens256) built"
echo "---------------------------------------------"
more ifcfg-ens256
sleep 3

#-----------------------------------------------------------------------------------------
# build ens256.VLAN
#-----------------------------------------------------------------------------------------
rm -rf ifcfg-ens256.$vlanID
cp ens256.woc ifcfg-ens256.$vlanID
echo VLAN_ID=$vlanID >> ifcfg-ens256.$vlanID
echo DEVICE=ens256.$vlanID >> ifcfg-ens256.$vlanID
echo "VLAN=yes" >> ifcfg-ens256.$vlanID
echo "IPADDR=100.64.250.100" >> ifcfg-ens256.$vlanID
echo "DEFROUTE=no" >> ifcfg-ens256.$vlanID
echo "GATEWAY=100.64.250.1" >> ifcfg-ens256.$vlanID
echo "PREFIX=24" >> ifcfg-ens256.$vlanID
cp ifcfg-ens256.$vlanID /etc/sysconfig/network-scripts/
echo "---------------------------------------------"
echo "Heartbeat Interface built"
echo "---------------------------------------------"
more ifcfg-ens256.$vlanID
sleep 3

#-----------------------------------------------------------------------------------------
# build ens224
#-----------------------------------------------------------------------------------------
rm -rf ifcfg-ens224
cp ens224.woc /etc/sysconfig/network-scripts/ifcfg-ens224
echo "---------------------------------------------"
echo "Internal Interface built"
echo "---------------------------------------------"
more /etc/sysconfig/network-scripts/ifcfg-ens224
sleep 3

#-----------------------------------------------------------------------------------------
# build ens224.VLAN
#-----------------------------------------------------------------------------------------
cp ens224.woc ifcfg-ens224.$vlanID
echo VLAN_ID=$vlanID >> ifcfg-ens224.$vlanID
echo DEVICE=ens224.$vlanID >> ifcfg-ens224.$vlanID
echo "VLAN=yes" >> ifcfg-ens224.$vlanID
echo "IPADDR=100.64.250.99" >> ifcfg-ens224.$vlanID
echo "DEFROUTE=no" >> ifcfg-ens224.$vlanID
echo "GATEWAY=100.64.250.1" >> ifcfg-ens224.$vlanID
echo "PREFIX=24" >> ifcfg-ens224.$vlanID
cp ifcfg-ens224.$vlanID /etc/sysconfig/network-scripts/ifcfg-ens224.$vlanID
echo "---------------------------------------------"
echo "Internal Failover Interface built"
echo "---------------------------------------------"
more ifcfg-ens224.$vlanID

systemctl restart network.service
	sleep 7 &
	PID=$!
	i=1
	sp="/-\|"
	echo -n ' '
	while [ -d /proc/$PID ]
	do
	  printf "\b${sp:i++%${#sp}:1}"
	done

clear

#grab interface mac addresses
#ens256Mac=$(ip -o link | awk '$2 == "ens256:" {print $(NF-2)}')

ls | grep load_var.woc
firstTime=($?)

if [[ $firstTime -eq 1 ]]; then
    echo "It looks like this is the first running this script, press enter to continue"
    read enter
else
    echo "WARNING! - running this script after initial setup will overrite previously stored values"
    echo "To prevent this, 'ctrl-c' out now! - otherwise [Enter] to continue if you intend to reset the woc parameters"
    echo " -----------------------------------------------------------------------------"
    echo "do you want to continue?"
    read firstTimeAns
    if [[ $firstTimeAns != "y" ]]; then
        exit
    fi
fi

clear

echo "Welcome to the Wireless Offload Concentrator / Tunneling Router setup!"
echo "There are 2 numbered interfaces, and 2 unnumbered interfaces needed for the WOC to properly function."
echo "The standard setup is as follows:"
echo "ens192 - External Interface - Dual stack interface and GREv6 source address of tunnel to the WAG for client traffic - this is the external interface"
echo "ens224 - Internal Interface - Unnumbered interface that faces the internal LAN segments "
echo "ens256 - Failover Test Interface"
echo " -----------------------------------------------------------------------------"
echo "Are the aforementioned interfaces present and linked appropriately? (y/n)"

read setupIntAns
if [ "$setupIntAns" == "y" ]
then
    rm -rf load_var.woc
    echo "Interface configuration accepted, here are your current interface parameters:"
    ip a
    echo "Is this interface configuration correct for your install?"
    read setupInt2Ans
        if [ "$setupInt2Ans" = "y" ]
        then
            echo "Please enter the WAG IPv6 endpoint address"
            echo "the ipv6 WAG address cannot be abbreviated with :: to hide zeros - enter the full address"
            read wagIpv6
            echo $wagIpv6 >> load_var.woc
        clear
        echo "The following parameters have been configured:"
        ipv6_wan=$(ip -6 addr show ens192 scope global | egrep -v dynamic | awk '$1 == "inet6" {print $2}' | awk '{print substr($1, 1, length($1)-3)}')
        echo "-------------------------------------------------------------------------"
        echo "The local IPv6 address for the dataplane tunnel is:"
        echo "$ipv6_wan"
        echo "-------------------------------------------------------------------------"
        echo "The WAG IPv6 endpoint is:"
        echo "$wagIpv6"
        echo "-------------------------------------------------------------------------"
        echo "Checking for presence of woc service file"

        ls /etc/systemd/system/ | grep woc.service
        serviceFile=($?)

        if [[ $serviceFile -eq "0" ]]; then
            echo "service file present"
        else
            echo "service file not round, load now? (y/n)"
            read loadService
            if [[ $loadService != "y" ]]; then
                echo "no service loaded, exiting"
                exit
            else
                echo "loading service"
                cp woc.service /etc/systemd/system/
                chmod +x /etc/systemd/system/woc.service
                ls /etc/systemd/system/ | grep woc.service
                cpStatus=($?)
                if [[ $cpStatus -eq 0 ]]; then
                    echo "serice file loaded!"
                else 
                    echo "an error occured, cannot find the service file, check permissions."
                    exit
                fi
            fi
        fi

        echo "Would you like to enable the service? (y/n)"
        read enableService
        if [[ $enableService != "y" ]]; then
            "service not enabled, the woc will not survive a reboot of the unit."
            exit
        else
            echo "enabling woc service"
            systemctl enable woc.service
            sleep 2
            echo "woc service enabled"
            
            #firewall-cmd --permanent --zone=trusted --add-source=$wagIpv6
            firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 0 -p gre -j ACCEPT
            firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 0 -p icmpv6 -s $wagIpv6 -j ACCEPT
            #sleep 2
            echo "restarting firewall"
            systemctl restart firewalld.service
            #systemctl stop firewalld.service
            #systemctl disable firewalld.service

        fi
        echo "If at any time you need to change these variables re-run the setup script!"
        echo "Press Enter to reboot to apply the new settings"
        echo $vlanID >> load_var.woc
        read pressEnter
        reboot
        else
            echo "please correct any misconfigured interfaces / links and restart the setup script"
                exit
        fi

else
        echo "please correct any misconfigured interfaces / links and restart the setup script"
        exit

fi
exit









