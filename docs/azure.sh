#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

notsupported() {
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
}

set -x

if [ "$(uname)" == 'Darwin' ]; then
  OS='Mac'
  notsupported
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  OS='Linux'
  # see https://qiita.com/koara-local/items/1377ddb06796ec8c628a
  if [ -e /etc/debian_version ] || [ -e /etc/debian_release ]; then
    if [ -e /etc/lsb-release ]; then
      DISTRIB="Ubuntu"
    else
      DISTRIB="Debian"
      notsupported
    fi
  else
    notsupported
  fi
elif [ "$(expr substr $(uname -s) 1 10)" == 'MINGW32_NT' ]; then
  OS='Cygwin'
  notsupported
else
  notsupported
fi

### read common functions ###
TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
curl -s https://pvtl.cf/jbox-common.sh -o ${TMPDIR}/common.sh
source ${TMPDIR}/common.sh
rm -rf ${TMPDIR}

install() {
  common_install
  common_install_docker

  ### make temporary directory ###
  TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  mkdir -p ${TMPDIR}

  set -euxo pipefail

  ### Azure CLI ###
  curl -L https://aka.ms/InstallAzureCli | bash

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
  mkdir -p $HOME/workspace/scripts
  cat <<EOT > ${HOME}/workspace/.envrc.tmpl
export S3_ACCESS_KEY_ID="***CHANGEMECHANGEME***"
export S3_SECRET_ACCESS_KEY="***CHANGEMECHANGEME***"

### OpsManager credentials
export ENV_NAME=aws
export MASTER_PASSWORD="***CHANGEMECHANGEME***"
export DOMAIN_NAME=pvtl.cf
export OM_HOSTNAME="om.\${ENV_NAME}.\${DOMAIN_NAME}"
export OM_USERNAME="admin"
export OM_PASSWORD=\${MASTER_PASSWORD}
export OM_DECRYPTION_PASSPHRASE=\${OM_PASSWORD}
export OM_TARGET="https://\${OM_HOSTNAME}"
export OM_SKIP_SSL_VALIDATION="true"

### BOSH credentials
eval "\$(om bosh-env)"
export BOSH_ALL_PROXY="ssh+socks5://ubuntu@\${OM_HOSTNAME}:22?private-key=\${HOME}/workspace/.opsman_ssh_key"

### VMware Tanzu Network credentials
export PIVNET_TOKEN="***CHANGEMECHANGEME***"
pivnet login --api-token=\${PIVNET_TOKEN}
EOT

cat <<EOT > ${HOME}/workspace/scripts/ssh-opsman.sh
#!/bin/bash
set -ex

if [ ! -f \$HOME/workspace/.opsman_ssh_key ]; then 
  mkdir -p \$HOME/.ssh
  ./scripts/terraforming.sh output-om \
      | om interpolate --path /ops_manager_ssh_private_key \
      > \$HOME/workspace/.opsman_ssh_key
  chmod 600 \$HOME/workspace/.opsman_ssh_key
fi
 
set +e
if [ ! -e \$HOME/.ssh/config ] || [ $(grep "Host opsman" \$HOME/.ssh/config | wc -l) -eq 0 ]; then
  touch \$HOME/.ssh/config
  cat <<EOF >> \$HOME/.ssh/config
ServerAliveInterval 30
 
Host opsman
  HostName \${OM_HOSTNAME}
  User ubuntu
  ForwardAgent yes
  IdentityFile %d/workspace/.opsman_ssh_key
EOF
fi
 
ssh opsman echo "***** I am your OpsManager! *****"
EOT
chmod +x ${HOME}/workspace/scripts/ssh-opsman.sh
}

conclusion() {
cat <<EOT


########### setup completed ##########

you may do steps below:

1. enable direnv and kubectl bash-completion
=====
source ~/.bash_profile
=====

2. prepare for direnv in workspace directory
=====
cd ~/workspace
cp .envrc.tmpl .envrc
vim .envrc
direnv allow
=====

3. save OpsManager SSH private key (manually, if not use Terraform)
=====
vim ~/workspace/.opsman_ssh_key
chmod 600 ~/workspace/.opsman_ssh_key
=====

4. (after OpsMan install) check SSH to OpsMan
=====
cd ~/workspace
./scripts/ssh-opsman.sh
=====

EOT
}

install
setup_homedir
conclusion