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

  ### TODO: My VMware CLI (vmw-cli) ###
  # see: https://github.com/apnex/vmw-cli

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
export ENV_PASSWORD='***CHANGEME***'
export ENV_NAME=haas-$(hostname | cut -d'-' -f 2)
export GOVC_URL="vcsa-01.\${ENV_NAME}.pez.vmware.com"
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD=${ENV_PASSWORD}
export GOVC_DATACENTER='Datacenter'
export GOVC_NETWORK='VM Network'
export GOVC_DATASTORE='LUN01'
export GOVC_RESOURCE_POOL='/Datacenter/host/Cluster'
export GOVC_INSECURE=1

export S3_ACCESS_KEY_ID="pezusers"
export S3_SECRET_ACCESS_KEY="***CHANGEME***"
export S3_ENDPOINT="s3.pez.vmware.com"
export S3_PIVNET_BUCKET="pipeline-factory"

export VMWUSER='***CHANGEME***'
export VMWPASS='***CHANGEME***'

export PIVNET_TOKEN="***CHANGEME***"
pivnet login --api-token=\$PIVNET_TOKEN

export OM_SSHKEY_FILEPATH='/tmp/opsman.pem'

export TKGIMC_HOST='***CHANGEME***'
export TKGIMC_PASSWORD=${ENV_PASSWORD}
if [ -v TKGIMC_HOST ]; then
  source ./scripts/env-tkgimc.sh
fi
EOF

  mkdir -p $HOME/workspace/scripts
  cat <<EOF > $HOME/workspace/scripts/env-tkgimc.sh
export OM_HOSTNAME=\$(curl -sk -u "root:\${TKGIMC_PASSWORD}" https://\${TKGIMC_HOST}/api/deployment/environment | jq -r '.[] | select(.key == "network.opsman_reachable_ip") | .value')
export OM_USERNAME=admin
export OM_PASSWORD=\$(curl -sk -u "root:\${TKGIMC_PASSWORD}" https://\${TKGIMC_HOST}/api/deployment/environment | jq -r '.[] | select(.key == "opsman.admin_password") | .value')
export OM_DECRYPTION_PASSPHRASE=\${OM_PASSWORD}
export OM_TARGET="https://\${OM_HOSTNAME}"
export OM_SKIP_SSL_VALIDATION="true"

curl -sk -u "root:\${TKGIMC_PASSWORD}" https://\${TKGIMC_HOST}/api/deployment/environment | jq -r '.[] | select(.key == "opsman.ssh_private_key") | .value' > \${OM_SSHKEY_FILEPATH}
chmod 600 \${OM_SSHKEY_FILEPATH}
export BOSH_ALL_PROXY="ssh+socks5://ubuntu@\${OM_HOSTNAME}:22?private-key=\${OM_SSHKEY_FILEPATH}"
eval "\$(om bosh-env)"
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
mosh ubuntu@ubuntu-???.haas-???.pez.vmware.com
tmux
=====

3. go to workspace directory and allow .envrc
=====
cd workspace
direnv allow
=====
EOT
}

install
setup_homedir
conclusion
