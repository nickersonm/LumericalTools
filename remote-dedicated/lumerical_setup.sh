#!/bin/bash
NEWUSER=user

# Debian container or dedicated Lumerical host
export PKGREM="snapd muon bind9* open-vm-tools packagekit* build-essential unattended-upgrades snapd"

# apt-get flags
export APTREM="-q --yes --fix-broken --auto-remove --purge"
export APTADD="$APTREM --no-install-recommends"


apt-get remove $APTREM $PKGREM

# Update repositories and install some basic required utilities
apt-get update
apt-get install $APTADD openssh-server nano zsh curl wget bash-completion samba samba-vfs-modules wireguard sudo

apt dist-upgrade $APTADD
apt-get remove $APTREM $PKGREM
apt-get clean


## Main user
echo "%admin  ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-admin
/usr/sbin/groupadd admin
/usr/sbin/adduser $NEWUSER admin
sudo -u $NEWUSER mkdir /home/$NEWUSER/.ssh
sudo -u $NEWUSER touch /home/$NEWUSER/.ssh/authorized_keys
echo "# Paste an authorized SSH key" >> /home/$NEWUSER/.ssh/authorized_keys
sudo -u $NEWUSER nano /home/$NEWUSER/.ssh/authorized_keys


## Samba for easy access via Windows clients
sudo smbpasswd -a "$USER"
sudo rm /etc/sambda/smb.conf
sudo tee /etc/samba/smb.conf <<EOT
[global]
  server role = standalone server
  hosts allow = 127.0.0.1 192.168.0.0/16 172.0.0.0/8
  hosts deny = 0.0.0.0/0
  server min protocol = SMB3_00
  dns proxy = no
  load printers = no

  # General file options
  access based share enum = yes
  inherit owner = yes
  inherit permissions = yes
  # Default to rw shares; any ro shares need to be specified explicitly
  writable = yes
  # Don't use unix extensions (unix/linux client exclusive, mostly resolving rather than following links)
  unix extensions = no
  # Allow cross-share symlinks
  wide links = yes

  # Map Windows/NFS4 ACLs
  vfs objects = acl_xattr
  map acl inherit = yes
  acl group control = yes

  # Performance tuning options
  # Improves performance over fast network
  socket options = TCP_NODELAY IPTOS_LOWDELAY
  use sendfile = true
  # Allow asynchronous reads
  aio read size = 1
  # require strict sync and no aio write to avoid issues with directory creation on Windows clients
  strict sync = yes
  aio write size = 0

  # Create homes directory if needed - required BEFORE connection is attempted to home
  root preexec = sh -c '[ -d "/home/%u" ] || ( mkdir -p "/home/%u"; chown %u "/home/%u"; chmod u+rwx,go-rwx "/home/%u" )'

# Home-directory shares
[homes]
  path = /home/%u
  comment = User home directory
  # Only accessible to the user
  browsable = no
EOT
sudo service smbd start
sudo systemctl enable smbd

## SSH customization
sudo tee /etc/ssh/sshd_config.d/custom.conf << EOT
Port 2022
PasswordAuthentication no
UseDNS no
AllowUsers root $NEWUSER
EOT
sudo service sshd restart


## Assuming Lumerical*.tar.gz is present
sudo apt-get install --no-install-recommends alien freeglut3 libxcb-xinerama0 tigervnc-standalone-server libglu1-mesa libxslt1.1 libqt5x11extras5 libltdl7
tar -xf Lumerical*.tar.gz
rm Lumerical*.tar.gz
cd Lumerical*/rpm_install_files
sudo alien -k --scripts Lumerical*.rpm
sudo dpkg -i lumerical*.deb
cd ../..
rm -rf Lumerical*
sudo apt-get remove --auto-remove --yes alien


## Install pueue
wget https://github.com/Nukesor/pueue/releases/download/v3.1.2/pueue-linux-x86_64 -O pueue
wget https://github.com/Nukesor/pueue/releases/download/v3.1.2/pueued-linux-x86_64 -O pueued
chmod a+x pueue*
sudo chown root pueue*
sudo mv pueue* /usr/bin/
pueued -d
pueue group add cad
pueue group add engine
pueue group add fdtd-engine
pueue parallel -g cad 8
pueue parallel -g engine 4
pueue parallel -g fdtd-engine 1
