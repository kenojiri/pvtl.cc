#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

### read common functions ###
TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
mkdir -p ${TMPDIR}
curl -sk https://pvtl.cf/jbox-common.sh -o ${TMPDIR}/jbox-common.sh
source ${TMPDIR}/jbox-common.sh
curl -sk https://pvtl.cf/vsphere-common.sh -o ${TMPDIR}/vsphere-common.sh
source ${TMPDIR}/vsphere-common.sh
rm -rf ${TMPDIR}

install() {
  ### change timezone to UTC ###
  sudo timedatectl set-timezone Etc/UTC

  common_install
  vsphere_vmd_install
  vsphere_install
}

setup_homedir() {
  common_add_ssh_pubkey
  common_setup_homedir
  vsphere_setup_homedir

  ### workspace directory ###
  cat <<EOF > $HOME/workspace/.envrc.template
export ENV_PASSWORD='***CHANGEME***'
export ENV_NAME=haas-$(hostname | cut -d'-' -f 2)
export GOVC_URL="vcsa-01.\${ENV_NAME}.pez.vmware.com"
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD=\${ENV_PASSWORD}
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
export VMD_USER=\${VMWUSER}
export VMD_PASS=\${VMWPASS}

export PIVNET_TOKEN="***CHANGEME***"
pivnet login --api-token=\$PIVNET_TOKEN

export OM_SSHKEY_FILEPATH='/tmp/opsman.pem'
export TKGIMC_HOST='***CHANGEME***'
export TKGIMC_PASSWORD=\${ENV_PASSWORD}
if [ -v TKGIMC_HOST ]; then
  source ./scripts/env-tkgimc.sh
fi
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
