#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

if test -z "$GITHUB_AUTH_CREDS"; then
  export CURL=curl
else
  export CURL="curl -k -u ${GITHUB_AUTH_CREDS}"
fi

prepare() {
  ### delete sources.list ###
  if [ -f /etc/apt/sources.list.d/influxdb.list ] ; then
    ## delete entry: deb https://repos.influxdata.com/ubuntu xenial stable
    sudo rm -f /etc/apt/sources.list.d/influxdb.list
  fi

  common_add_ssh_pubkey

  ### upgrading Ubuntu ###
  source /etc/lsb-release

  # 16.04 (xenial)
  if [ $DISTRIB_CODENAME = "xenial" ]; then
    ### add sources.list ###
    sudo sh -c 'echo "deb https://build-artifactory.eng.vmware.com/artifactory/ubuntu-remote/ xenial main restricted universe multiverse" > /etc/apt/sources.list.d/VMW-internal-mirror-xenial.list'

    sudo apt-get update
    sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
    sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
    sudo do-release-upgrade -f DistUpgradeViewNonInteractive
    sudo mv /etc/resolv.conf /etc/resolv.conf.org && sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    sudo reboot
  fi

  # 18.04 (bionic)
  if [ $DISTRIB_CODENAME = "bionic" ]; then
    if [ $(uname -r | awk -F- '{print $1}') != "4.15.0" ]; then
      sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -f -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
      sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
      sudo reboot
    fi

    ### add sources.list ###
    if [ -f /etc/apt/sources.list.d/VMW-internal-mirror-xenial.list ]; then
      sudo rm -f /etc/apt/sources.list.d/VMW-internal-mirror-xenial.list
    fi
    sudo sh -c 'echo "deb https://build-artifactory.eng.vmware.com/artifactory/ubuntu-remote/ bionic main restricted universe multiverse" > /etc/apt/sources.list.d/VMW-internal-mirror-bionic.list'

    sudo apt-get update
    sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
    sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
    sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes -o Dpkg::Options::=\"--force-confnew\" update-manager-core"
    sudo do-release-upgrade -f DistUpgradeViewNonInteractive
    sudo reboot
  fi

  # 20.04 (focal)
  if [ $DISTRIB_CODENAME = "focal" ]; then
    if [ $(uname -r | awk -F- '{print $1}') != "5.4.0" ]; then
      sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -f -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
      sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
      sudo reboot
    fi

    ### add sources.list ###
    if [ -f /etc/apt/sources.list.d/VMW-internal-mirror-xenial.list ]; then
      sudo rm -f /etc/apt/sources.list.d/VMW-internal-mirror-xenial.list
    fi
    if [ -f /etc/apt/sources.list.d/VMW-internal-mirror-bionic.list ]; then
      sudo rm -f /etc/apt/sources.list.d/VMW-internal-mirror-bionic.list
    fi
    sudo sh -c 'echo "deb https://build-artifactory.eng.vmware.com/artifactory/ubuntu-remote/ focal main restricted universe multiverse" > /etc/apt/sources.list.d/VMW-internal-mirror-focal.list'

    sudo apt-get update
    sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
    sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
  fi

  # 22.04 (jammy)
  if [ $DISTRIB_CODENAME = "jammy" ]; then
    sudo sh -c 'echo "deb https://build-artifactory.eng.vmware.com/artifactory/ubuntu-remote/ jammy main restricted universe multiverse" > /etc/apt/sources.list.d/VMW-internal-mirror-jammy.list'

    sudo apt-get update
    sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
    sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --force-yes -o Dpkg::Options::=\"--force-confnew\""
  fi

  sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --force-yes -o Dpkg::Options::=\"--force-confnew\""

  ### change timezone to UTC ###
  sudo timedatectl set-timezone Etc/UTC
}

install() {
  common_install

  vsphere_install
  vsphere_vmd_install

  sudo wget "https://runway-ci.eng.vmware.com/api/v1/cli?arch=amd64&platform=linux" -O fly
  sudo install ./fly /usr/local/bin/
  sudo chmod +x /usr/local/bin/fly

  sudo wget "https://runway.eng.vmware.com/cli/2.0.0/linux/runctl" -O runctl
  sudo install ./runctl /usr/local/bin/
  sudo chmod +x /usr/local/bin/runctl
}

setup_homedir() {
  common_setup_homedir

  if [ $(lsblk | grep /data | wc -l) -gt 0 ]; then
    ### use /data partition for ~/workspace directory ###
    sudo mkdir -p /data/workspace
    sudo chown worker.worker /data/workspace
    ln -s /data/workspace ${HOME}/workspace
  else
    mkdir -p ${HOME}/workspace
  fi

  vsphere_setup_homedir

  ### workspace directory ###
  cat <<EOF > $HOME/workspace/.envrc.template
export VMWUSER='***CHANGEME***'
export VMWPASS='***CHANGEME***'
export VMD_USER=\${VMWUSER}
export VMD_PASS=\${VMWPASS}

# see https://runway.eng.vmware.com/docs/#/components/platform/authentication?id=refreshing-token-with-api-token
export RUNWAY_TOKEN="***CHANGEME***"
runctl login --auth \$RUNWAY_TOKEN

export PIVNET_TOKEN="***CHANGEME***"
pivnet login --api-token=\$PIVNET_TOKEN

EOF
}

conclusion() {
cat <<EOT

########### setup completed ##########

you may do steps below:

1. create workspace/.envrc from template
=====
cp workspace/.envrc.template workspace/.envrc
vim workspace/.envrc
=====

2. re-login via mosh and start tmux
=====
exit
mosh ***@nimbus.pvtl.cc
tmux
=====

3. go to workspace directory and allow .envrc
=====
cd workspace
direnv allow
=====
EOT
}
