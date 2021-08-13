#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

if test -z "$GITHUB_AUTH_CREDS"; then
  export CURL=curl
else
  export CURL="curl -u ${GITHUB_AUTH_CREDS}"
fi

### read common functions ###
TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
mkdir -p ${TMPDIR}
curl -s https://pvtl.cf/jbox-common.sh -o ${TMPDIR}/jbox-common.sh
source ${TMPDIR}/jbox-common.sh
curl -s https://pvtl.cf/vsphere-common.sh -o ${TMPDIR}/vsphere-common.sh
source ${TMPDIR}/vsphere-common.sh
rm -rf ${TMPDIR}

install() {

  ### add sources.list ###
  sudo sh -c echo "deb https://build-artifactory.eng.vmware.com/artifactory/ubuntu-remote/ focal main restricted universe multiverse" > /etc/apt/sources.list.d/VMW-internal-mirror.list

  common_install_docker
  common_install
  vsphere_install

  sudo wget "https://runway-ci.eng.vmware.com/api/v1/cli?arch=amd64&platform=linux" -O fly
  sudo install -m 755 ./fly /usr/local/bin/

  sudo wget "https://runway.eng.vmware.com/cli/2.0.0/linux/runctl" -O runctl
  sudo install -m 755 ./runctl /usr/local/bin/
}

setup_homedir() {
  common_setup_homedir
  vsphere_setup_homedir

  ### workspace directory ###
  cat <<EOF > $HOME/workspace/.envrc.template
export ENV_PASSWORD='***CHANGEME***'
export ENV_NAME=blr
export GOVC_URL="kitkat-vc.eng.vmware.com"
export GOVC_USERNAME='administrator@kitkat-lab.local'
export GOVC_PASSWORD=\${ENV_PASSWORD}
export GOVC_DATACENTER='kitkat-lab vSAN Datacenter'
export GOVC_NETWORK='vDS1 - DC Data Network VLAN1012'
export GOVC_DATASTORE='vsanDatastore'
export GOVC_RESOURCE_POOL='/kitkat-lab vSAN Datacenter/host/kitkat-lab vSAN Cluster'
export GOVC_INSECURE=1

export VMWUSER='***CHANGEME***'
export VMWPASS='***CHANGEME***'

# see https://runway.eng.vmware.com/docs/#/components/platform/authentication?id=refreshing-token-with-api-token
export RUNWAY_TOKEN="***CHANGEME***"
runway login --auth \$RUNWAY_TOKEN

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
mosh ubuntu@blr.pvtl.cf
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
