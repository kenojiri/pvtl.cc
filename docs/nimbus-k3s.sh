#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

if [ -z "$GITHUB_AUTH_CREDS" -o -z "$NEW_HOSTNAME" ] ; then
  echo "Please run this script with GITHUB_AUTH_CREDS and NEW_HOSTNAME," >&2
  echo "such as 'curl -skL https://pvtl.cc/nimbus-k3s.sh | GITHUB_AUTH_CREDS=**** NEW_HOSTNAME=nimbus?? bash'" >&2
  exit 1
else
  CURL="curl -uk ${GITHUB_AUTH_CREDS}"
  echo ${NEW_HOSTNAME} | sudo tee /etc/hostname
  cat << EOF | sudo tee /etc/hosts
127.0.0.1       localhost
127.0.1.1       ${NEW_HOSTNAME}
EOF
fi

set -x

### read common functions ###
TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
mkdir -p ${TMPDIR}
curl -sk https://pvtl.cc/jbox-common.sh -o ${TMPDIR}/jbox-common.sh
source ${TMPDIR}/jbox-common.sh
curl -sk https://pvtl.cc/vsphere-common.sh -o ${TMPDIR}/vsphere-common.sh
source ${TMPDIR}/vsphere-common.sh
curl -sk https://pvtl.cc/nimbus-common.sh -o ${TMPDIR}/nimbus-common.sh
source ${TMPDIR}/nimbus-common.sh
rm -rf ${TMPDIR}

prepare
install
common_install_k3s_master
setup_homedir
conclusion
