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

vsphere_install() {
  ### make temporary directory ###
  TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  mkdir -p ${TMPDIR}

  ### deb packages - mosh, OpenVPN ###
  echo "Installing deb packages..."
  sudo apt-get update
  sudo apt-get install -y mosh openvpn

  ### vCenter CLI (govc) ###
  VERSION=$(${CURL} -s https://api.github.com/repos/vmware/govmomi/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -LO https://github.com/vmware/govmomi/releases/download/v0.23.0/govc_linux_amd64.gz
    gunzip govc_linux_amd64.gz
    sudo install -m 755 ./govc_linux_amd64 /usr/local/bin/govc
  popd

  ### remove temporary directory ###
  rm -rf ${TMPDIR}
}

vsphere_vmw_cli_install() {
  ### make temporary directory ###
  TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  mkdir -p ${TMPDIR}

  ### My VMware CLI (vmw-cli) ###
  # see: https://github.com/apnex/vmw-cli
  sudo docker run harbor-repo.vmware.com/dockerhub-proxy-cache/apnex/vmw-cli shell > ${TMPDIR}/vmw-cli
  sudo install -m 755 ${TMPDIR}/vmw-cli /usr/local/bin/

  ### remove temporary directory ###
  rm -rf ${TMPDIR}
}

vsphere_vmd_install() {
  ### make temporary directory ###
  TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  mkdir -p ${TMPDIR}

  ### vmd CLI ###
  VERSION=$(${CURL} -s https://api.github.com/repos/laidbackware/vmd/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -LO https://github.com/laidbackware/vmd/releases/download/${VERSION}/vmd-linux-${VERSION}
    sudo install -m 755 ./vmd-linux-* /usr/local/bin/vmd
  popd

  ### remove temporary directory ###
  rm -rf ${TMPDIR}
}

vsphere_setup_homedir() {
  ### workspace directory ###
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
