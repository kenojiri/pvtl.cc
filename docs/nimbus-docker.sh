#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

if [ -z "$GITHUB_AUTH_CREDS" ] ; then
  echo "Please run this script with GITHUB_AUTH_CREDS," >&2
  echo "such as 'curl -skL https://pvtl.cc/nimbus-docker.sh | GITHUB_AUTH_CREDS=**** bash'" >&2
  exit 1
else
  CURL="curl -uk ${GITHUB_AUTH_CREDS}"
fi

set -x

### read common functions ###
TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
mkdir -p ${TMPDIR}
curl -sk https://pvtl.cc/common.sh -o ${TMPDIR}/common.sh
source ${TMPDIR}/common.sh
rm -rf ${TMPDIR}

### deb packages ###
echo "Installing deb packages..."
sudo apt-get update
sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
  -o Dpkg::Options::="--force-confnew" \
  git mosh tmux jq direnv unzip groff netcat-openbsd bash-completion sshpass \
  dnsmasq chrony net-tools dnsutils ldap-utils nfs-common nfs-kernel-server \
  apt-transport-https gnupg software-properties-common"

common_docker_install
common_yj_install
common_mc_install
common_pivnet_install
common_terraform_install
common_vault_install
common_carvel_install
common_krew_install
common_helm_install
common_velero_install
common_stern_install
common_govc_install
common_vcc_install
common_flarectl_install
common_setup_homedir_kubectl
common_setup_homedir_starship
common_setup_homedir_direnv
common_setup_homedir_tmux
#
