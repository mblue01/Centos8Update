#!/bin/bash
# SCRIPT TO SET DEFAULT INSTALL FOR NEW CENTOS 8 BUILDS
### The BASH script should be run on any new CENTOS 8 server....  It performs basic updating, configuration, and security....
### Run as root!

####################################CHECK FOR ROOT################################
ROOT_UID=0 #Root has $UID 0
SUCCESS=0
E_USEREXISTS=70
E_NOTROOT=65 #Not root
###Run as root, and this checks to see if the creater is in root. If not, will not run
if [ "$UID" -ne "$ROOT_UID" ]; then
echo "Sorry must be in root to run this script"
exit $E_NOTROOT
fi

################################## YUM UPDATE ####################################
echo "*********************************************************************"
echo "*********************************************************************"
echo "UPDATING SYSTEM WITH YUM"
echo "*********************************************************************"
###set your timezone here:
timedatectl set-timezone America/New_York 
yum -y install epel-release nano
yum -y update
echo "*********************************************************************"
echo "*********************************************************************"
echo "YUM UPDATE COMPLETE"
echo "*********************************************************************"
echo "*********************************************************************"
echo "*********************************************************************"

############################# ##SETUP USER ######################################
echo "*************************Setup a non-root user.**********************"
echo "*********************************************************************"
echo "What is your new username: "
read user
echo "Type in the password: "
read -s passwd
useradd $user -d /home/$user -m;
echo $passwd | passwd $user --stdin;

############################ Adds new user to sudoers #####################
usermod -aG wheel $user
echo "*********************************************************************"
echo "*********************************************************************"
echo "*********************************************************************"
echo "The user $user has been setup!"
echo "*********************************************************************"
echo "*********************************************************************"

########################### Auto Security Updates ##########################
echo "INSTALL DNF AUTOMATIC to run security updates automatically"
dnf install -y dnf-automatic
### UPDATE /etc/dnf/automatic.conf 
echo "UPDATING DNF AUTOMATIC.CONF FILE"
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
sed -i 's/upgrade_type = default/upgrade_type = security/' /etc/dnf/automatic.conf
systemctl enable dnf-automatic.timer && systemctl start dnf-automatic.timer
echo "*********************************************************************"
echo "*********************************************************************"
echo "DNF SET TO AUTOUPDATE SECURITY PATCHES"
echo "*********************************************************************"
echo "*********************************************************************"

############################# Setup System Hostname ########################
echo "SETUP YOUR HOSTNAME"
echo "What is your system's hostname? e.g. gbviper.gbarcc.com "
read hostnm
hostnamectl set-hostname "$hostnm"
### EDIT HOSTS FILE ###
echo "EDIT HOSTS FILE"
sed -i "/127/{s/:/ /g;s/.*=//;s/$/ $hostnm/p}" /etc/hosts
echo "*********************************************************************"
echo "*********************************************************************"
echo "/etc/hosts file updated"
echo "*********************************************************************"
echo "*********************************************************************"

##################### Disable IPV6 ##################
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

##################### Create more robust hostfile logging ##################
echo 'export HISTSIZE=' >> ~/.bashrc
echo 'export HISTSIZE=' >> /home/$usernm/.bashrc
echo 'export HISTFILESIZE=' >> ~/.bashrc
echo 'export HISTFILESIZE=' >> /home/$usernm/.bashrc
echo 'export HISTCONTROL=ignoredups:erasedups' >> ~/.bashrc
echo 'export HISTCONTROL=ignoredups:erasedups' >> /home/$usernm/.bashrc
echo 'shopt -s histappend' >> ~/.bashrc
echo 'shopt -s histappend' >> /home/$usernm/.bashrc
echo "export PROMPT_COMMAND=\"\${PROMPT_COMMAND:+\$PROMPT_COMMAND$'\n'}history -a; history -c; history -r\"" >> ~/.bashrc
echo "export PROMPT_COMMAND=\"\${PROMPT_COMMAND:+\$PROMPT_COMMAND$'\n'}history -a; history -c; history -r\"" >> /home/$usernm/.bashrc
echo "*********************************************************************"
echo "*********************************************************************"
echo ".bashrc history updated"
echo "*********************************************************************"
echo "*********************************************************************"

########################## LIMIT ROOT ONLY TO TTY1 #############################
cp /etc/securetty /etc/securetty.bak
echo "tty1" > /etc/securetty

######################### LOCK DOWN ROOT FOLDER TO ONLY ROOT ###################
chmod 700 /root

############################ CONFIGURE SSHD #################################
### What Port?
echo "What TCP port should sshd run on?"
read sshPort
### Root login not allowed
sed -i "/PermitRootLogin yes/c\PermitRootLogin no" /etc/ssh/sshd_config
### Only Protocol 2 - write on line after Port
sed -i 's/.*Port 22.*/&\nProtocol 2/' /etc/ssh/sshd_config
### SSHD Port - set here and in FW
sed -i "s/#Port 22/Port $sshPort/" /etc/ssh/sshd_config
### Avoid breaking Xforwarding w/ ipv6 disabled
sed -i "s/#AddressFamily any/AddressFamily inet/" /etc/ssh/sshd_config
### Restart sshd
systemctl restart sshd
echo "SSHD Configuration Complete..."

############################ CONFIGURE FAIL2BAN #############################
### TEST THIS!!!
#echo Setting up fail2ban...
#yum install -y fail2ban
#cd /etc/fail2ban
#cp fail2ban.conf fail2ban.local
#cp jail.conf jail.local
#sed -i -e "s/backend = auto/backend = systemd/" /etc/fail2ban/jail.local
#systemctl enable fail2ban
#systemctl start fail2ban
#echo "FAIL2BAN Setup Complete..."

########################### FIREWALL-D CONFIG - ####################
echo "Setup Firewalld"
systemctl enable firewalld
systemctl start firewalld
echo "firewall update"
firewall-cmd --add-port $sshPort/tcp --permanent
echo "firewall update"
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT_direct 0 -p tcp --dport $sshPort -m state --state NEW -m recent --set
echo "firewall update"
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT_direct 1 -p tcp --dport $sshPort -m state --state NEW -m recent --update --seconds 30 --hitcount 4 -j REJECT --reject-with tcp-reset
echo "firewall update"
firewall-cmd --reload
echo "Firewalld configuration complete... "

echo "########################################################################"
echo "########################################################################"
echo "########################################################################"
echo "######################## CONFIG COMPLETE ################################"
echo "####################### SSHD  on port $sshPort###########################"
echo "########################################################################"
echo "########################################################################"
echo "########################################################################"
