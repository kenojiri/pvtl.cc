#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

### read common functions ###
TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
mkdir -p ${TMPDIR}
curl -s https://pvtl.cf/jbox-common.sh -o ${TMPDIR}/common.sh
source ${TMPDIR}/common.sh
rm -rf ${TMPDIR}

install() {
  common_install

  ### make temporary directory ###
  TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  mkdir -p ${TMPDIR}

  set -euxo pipefail

  ### deb packages - mosh, OpenVPN ###
  echo "Installing deb packages..."
  sudo apt-get update
  sudo apt-get install -y mosh openvpn

  ### vCenter CLI (govc) ###
  VERSION=$(curl -s https://api.github.com/repos/vmware/govmomi/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -LO https://github.com/vmware/govmomi/releases/download/v0.23.0/govc_linux_amd64.gz
    gunzip govc_linux_amd64.gz
    sudo install -m 755 ./govc_linux_amd64 /usr/local/bin/govc
  popd

  ### remove temporary directory ###
  rm -rf ${TMPDIR}
}

setup_homedir() {
  common_setup_homedir

  ### SSH via key ###
  if [ ! -f $HOME/.ssh/authorized_keys ] || ! grep -q ssh-import-id $HOME/.ssh/authorized_keys ; then
    github_id="${GITHUB_ID:-kenojiri}"
    echo "Installing SSH public key..."
    ssh-import-id-gh $github_id
  fi

  ### workspace directory ###
  mkdir -p $HOME/workspace
  cat <<EOF > $HOME/workspace/.envrc.template
export ENV_NAME=haas-$(hostname | cut -d'-' -f 2)
export GOVC_URL="vcsa-01.\${ENV_NAME}.pez.vmware.com"
#export GOVC_URL="vcsa-01.\${ENV_NAME}.pez.pivotal.io"
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='***CHANGEME***'
export GOVC_DATACENTER='Datacenter'
export GOVC_NETWORK='Extra'
export GOVC_DATASTORE='LUN01'
export GOVC_RESOURCE_POOL='/Datacenter/host/Cluster/Resources/tkg'
export GOVC_INSECURE=1

export S3_ACCESS_KEY_ID="pezusers"
export S3_SECRET_ACCESS_KEY="***CHANGEME***"
export S3_ENDPOINT="s3.pez.vmware.com"
#export S3_ENDPOINT="s3.pez.pivotal.io"
export S3_PIVNET_BUCKET="pipeline-factory"

export PIVNET_TOKEN="***CHANGEME***"
pivnet login --api-token=\$PIVNET_TOKEN
EOF
}

conclusion() {
cat <<EOT

########### setup completed ##########

you may do steps below:

1. enable direnv and kubectl bash-completion
=====
source ~/.bash_profile
=====

EOT
}

install
setup_homedir
conclusion
