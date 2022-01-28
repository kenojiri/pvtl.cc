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
mkdir -p ${TMPDIR}
curl -s https://pvtl.cf/jbox-common.sh -o ${TMPDIR}/common.sh
source ${TMPDIR}/common.sh
rm -rf ${TMPDIR}

install() {
  common_install
  common_install_docker

  ### make temporary directory ###
  TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  mkdir -p ${TMPDIR}

  ### AWS CLI ###
  pushd ${TMPDIR}
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
  popd

  ### remove temporary directory ###
  rm -rf ${TMPDIR}
}

setup_homedir() {
  common_add_ssh_pubkey
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
### AWS credentials
export AWS_ACCESS_KEY_ID="***CHANGEMECHANGEME***"
export AWS_SECRET_ACCESS_KEY="***CHANGEMECHANGEME***"
#tokyo#export AWS_DEFAULT_REGION="ap-northeast-1"
#osaka#export AWS_DEFAULT_REGION="ap-northeast-3"
#singapore#export AWS_DEFAULT_REGION="ap-southeast-1"
export AWS_DEFAULT_REGION="ap-southeast-1"
export AWS_IAM_USER_NAME="tanzu"
export DNS_ZONE="pvtl.cf."

export S3_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID}
export S3_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY}

### OpsManager credentials
export ENV_NAME=aws
export MASTER_PASSWORD="***CHANGEMECHANGEME***"
export DOMAIN_NAME=$(echo $DNS_ZONE | sed -e "s/.\$//")
export OM_HOSTNAME="opsmanager.\${ENV_NAME}.\${DOMAIN_NAME}"
export OM_USERNAME="admin"
export OM_PASSWORD=\${MASTER_PASSWORD}
export OM_DECRYPTION_PASSPHRASE=\${OM_PASSWORD}
export OM_TARGET="https://\${OM_HOSTNAME}"
export OM_SKIP_SSL_VALIDATION="true"

### BOSH credentials
export BOSH_ALL_PROXY="ssh+socks5://ubuntu@\${OM_HOSTNAME}:22?private-key=\${HOME}/workspace/.opsman_ssh_key"
if [ \$(\$(nc -zw 1 \${OM_HOSTNAME} 443); echo \$?) -eq 0 ]; then
  eval "\$(om bosh-env)"
fi

### VMware Tanzu Network credentials
export PIVNET_TOKEN="***CHANGEMECHANGEME***"
pivnet login --api-token=\${PIVNET_TOKEN}

### TKGI credentials
if [ -v BOSH_CLIENT ]; then
  if [ \$(om products --deployed -f json | grep pivotal-container-service | wc -l
) -gt 0 ]; then
    export PKS_USER_PASSWORD=\$(om credentials -p pivotal-container-service -c .p
roperties.uaa_admin_password -f secret)
    TKGI_API_HOST=\$(./2_terraforming.sh output-pks | om interpolate --path=/pks_
api_dns)
    tkgi login -a \${TKGI_API_HOST} -k -u admin -p \${PKS_USER_PASSWORD}
  fi
fi
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
