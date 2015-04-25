#!/bin/bash
clear

# Cleanup
echo "# Cleaning up prior installs"
sudo userdel stack
sudo sed -i -e 's/stack ALL=(ALL) NOPASSWD: ALL//g' /etc/sudoers
sudo rm -rf /home/stack
sudo rm -rf /opt/stack
rm -rf ./stack.basrc
rm -rf ./devstack
rm -rf ./heat-templates

echo ""

# Install prerequisites
echo "# Installing dependencies..."
sudo dpkg-query -l git | grep "no package" > /tmp/git.tmp
if [ `cat /tmp/git.tmp` == "" ]; then
	echo "All dependencies installed."
else
	echo "Installing git."
	sudo apt-get -y install git > /dev/null
fi

echo ""

# Setup stack user
echo "# Setting up stack user..."
if sudo grep stack /etc/passwd > /dev/null; then
        echo "Stack user already exists."
else
        sudo useradd -d /home/stack -m stack
	sudo sh -c "echo 'stack:stack' | chpasswd"
	
# Set stack.sh to run on first login
cat <<'EOF' > ./stack.bashrc

if [ -d "/opt/stack" ] ; then
    echo "Devstack installed"
else
    echo "Installing Devstack"
    cd /home/stack/devstack
    ./stack.sh
fi
EOF
	sudo sh -c "cat ./stack.bashrc >> /home/stack/.bashrc"
	echo "Stack user added."
fi

echo ""

echo "# Adding stack user to sudoers..."
if sudo grep stack /etc/sudoers > /dev/null; then
        echo "Stack user already in sudoers"
else
	echo "Added stack user to sudoers"
        sudo sh -c "echo 'stack ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"
fi

echo ""

# Download and install devstack
git clone https://github.com/openstack-dev/devstack.git ./devstack/ > /dev/null
git clone https://github.com/openstack/heat-templates.git ./heat-templates/ > /dev/null

# Install and configure devstack
cat <<'EOF' > ./devstack/local.conf
[[local|localrc]]

# Auth Info
ADMIN_PASSWORD=stack
DATABASE_PASSWORD=$ADMIN_PASSWORD
RABBIT_PASSWORD=$ADMIN_PASSWORD
SERVICE_PASSWORD=$ADMIN_PASSWORD
SERVICE_TOKEN=$ADMIN_PASSWORD

# Branches
KEYSTONE_BRANCH=stable/kilo
NOVA_BRANCH=stable/kilo
NEUTRON_BRANCH=stable/kilo
SWIFT_BRANCH=stable/kilo
GLANCE_BRANCH=stable/kilo
CINDER_BRANCH=stable/kilo
HEAT_BRANCH=stable/kilo
TROVE_BRANCH=stable/kilo
HORIZON_BRANCH=stable/kilo
SAHARA_BRANCH=stable/kilo

# Hard set host ip as needed in multi-nic / multi-ip configurations
# HOST_IP=172.16.80.110

## Disable unwanted services
# Nova network and extra neutron services
disable_service n-net
disable_service q-fwaas
disable_service q-vpn
# Tempest services
disable_service tempest
# Sahara
disable_service sahara
# Trove services
disable_service trove
disable_service tr-api
disable_service tr-mgr
disable_service tr-cond
# Swift services
disable_service s-proxy
disable_service s-object
disable_service s-container
disable_service s-account

# Enable Cinder services
enable_service cinder
enable_service c-api
enable_service c-vol
enable_service c-sch
enable_service c-bak

# Enable Database Backend MySQL
enable_service mysql

# Enable RPC Backend RabbitMQ
enable_service rabbit

# Enable Keystone - OpenStack Identity Service
enable_service key  

# Enable Horizon - OpenStack Dashboard Service
enable_service horizon

# Enable Glance -  OpenStack Image service 
enable_service g-api
enable_service g-reg

# Enable Neutron - Networking Service
enable_service q-svc
enable_service q-agt
enable_service q-dhcp
enable_service q-l3
enable_service q-meta
enable_service q-lbaas
enable_service neutron

# VLAN configuration.
# Q_PLUGIN=ml2
# ENABLE_TENANT_VLANS=True

# GRE tunnel configuration
Q_PLUGIN=ml2
ENABLE_TENANT_TUNNELS=True

# VXLAN tunnel configuration
# Q_PLUGIN=ml2
# Q_ML2_TENANT_NETWORK_TYPE=vxlan

# Enable Ceilometer - Metering Service (metering + alarming)
enable_service ceilometer-acompute
enable_service ceilometer-acentral
enable_service ceilometer-anotification
enable_service ceilometer-api
enable_service ceilometer-alarm-notifier
enable_service ceilometer-alarm-evaluator

# Enable Heat - Orchestration Service
enable_service heat
enable_service h-api
enable_service h-api-cfn
enagle_service h-api-cw
enable_service h-eng

# Images
IMAGE_URLS+="http://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img"

# Output
LOGFILE=/opt/stack/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=False
SCREEN_LOGDIR=/opt/stack/logs
EOF

# Copy files and fix permissions
sudo cp -rf ./devstack /home/stack/
sudo cp -rf ./heat-templates /home/stack/
sudo chown -R stack:stack /home/stack/*

# Change to stack user
cd /home/stack
sudo su stack
