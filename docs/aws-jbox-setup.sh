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
 
install() {
### make temporary directory ###
TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
mkdir -p ${TMPDIR}

set -euxo pipefail

### deb packages ###
sudo apt-get update
sudo apt-get install -y \
  wget curl git jq zip vim tmux tree pwgen direnv bash-completion \
  build-essential zlibc zlib1g-dev libssl-dev libreadline-dev \
  ruby ruby-dev \
  apt-transport-https gnupg software-properties-common \
  groff netcat-openbsd

### BOSH CLI ###
VERSION=$(curl -s https://api.github.com/repos/cloudfoundry/bosh-cli/releases/latest | jq -r .name | tr -d 'v')
curl -vL https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${VERSION}-linux-amd64 -o ${TMPDIR}/bosh
sudo install -m 755 ${TMPDIR}/bosh /usr/local/bin/bosh

### CF CLI ###
wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list
sudo apt-get update
sudo apt-get install -y cf-cli
sudo curl -vL https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf -o /usr/share/bash-completion/completions/cf

### UAA CLI ###
sudo gem install cf-uaac

### BOSH Backup and Restore CLI (bbr) ###
VERSION=$(curl -s https://api.github.com/repos/cloudfoundry-incubator/bosh-backup-and-restore/releases/latest | jq -r .tag_name | sed 's/v//')
curl -vL https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/download/${VERSION}/bbr-${VERSION}-linux-amd64 -o ${TMPDIR}/bbr
sudo install -m 755 ${TMPDIR}/bbr /usr/local/bin/bbr

### CredHub CLI ###
VERSION=$(curl -s https://api.github.com/repos/cloudfoundry-incubator/credhub-cli/releases/latest | jq -r .tag_name)
pushd ${TMPDIR}
  curl -vL https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/${VERSION}/credhub-linux-${VERSION}.tgz | tar zxvf -
  sudo install -m 755 ./credhub /usr/local/bin/credhub
popd

### Concourse CLI ###
VERSION="6.3.0"
pushd ${TMPDIR}
  curl -vL https://github.com/concourse/concourse/releases/download/v${VERSION}/fly-${VERSION}-linux-amd64.tgz | tar zxvf -
  sudo install -m 755 ./fly /usr/local/bin/fly
popd

### HashiCorp Terraform ###
VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r .tag_name | sed 's/v//')
curl -vL https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_linux_amd64.zip -o ${TMPDIR}/terraform.zip
cd /usr/local/bin
sudo unzip -u ${TMPDIR}/terraform.zip

### Kubernetes CLI (kubectl) ###
VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
pushd ${TMPDIR}
  curl -LO https://storage.googleapis.com/kubernetes-release/release/${VERSION}/bin/linux/amd64/kubectl
  sudo install -m 755 ./kubectl /usr/local/bin/kubectl
popd

### Helm 2 ###
VERSION="v2.16.9"
pushd ${TMPDIR}
  curl -vL https://get.helm.sh/helm-${VERSION}-linux-amd64.tar.gz -o helm.tgz
  tar zxvf helm.tgz linux-amd64/
  sudo install -m 755 linux-amd64/helm /usr/local/bin/helm2
  sudo install -m 755 linux-amd64/tiller /usr/local/bin/tiller
popd

### Helm 3 ###
VERSION="v3.2.4"
pushd ${TMPDIR}
  curl -vL https://get.helm.sh/helm-${VERSION}-linux-amd64.tar.gz -o helm.tgz
  tar zxvf helm.tgz linux-amd64/
  sudo install -m 755 linux-amd64/helm /usr/local/bin/helm
popd

### VMware Tanzu Network CLI (pivnet) ###
VERSION=$(curl -s https://api.github.com/repos/pivotal-cf/pivnet-cli/releases/latest | jq -r .tag_name | sed 's/v//')
curl -vL https://github.com/pivotal-cf/pivnet-cli/releases/download/v${VERSION}/pivnet-linux-amd64-${VERSION} -o ${TMPDIR}/pivnet
sudo install -m 755 ${TMPDIR}/pivnet /usr/local/bin/pivnet

### Ops Manager CLI (om) ###
VERSION=$(curl -s https://api.github.com/repos/pivotal-cf/om/releases/latest | jq -r .tag_name)
curl -vL https://github.com/pivotal-cf/om/releases/download/${VERSION}/om-linux-${VERSION} -o ${TMPDIR}/om
sudo install -m 755 ${TMPDIR}/om /usr/local/bin/om

### k14s (ytt, kbld, kapp, imgpkg, vendir, kwt, and etc.) ###
curl -vL https://k14s.io/install.sh | sudo bash

### yj ###
VERSION=$(curl -s https://api.github.com/repos/sclevine/yj/releases/latest | jq -r .tag_name)
curl -vL https://github.com/sclevine/yj/releases/download/${VERSION}/yj-linux -o ${TMPDIR}/yj
sudo install -m 755 ${TMPDIR}/yj /usr/local/bin/yj

### minio CLI (mc) ###
curl -vL https://dl.minio.io/client/mc/release/linux-amd64/mc -o ${TMPDIR}/mc
sudo install -m 755 ${TMPDIR}/mc /usr/local/bin/mc

### Velero CLI ###
VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | jq -r .tag_name)
pushd ${TMPDIR}
  curl -vL https://github.com/vmware-tanzu/velero/releases/download/${VERSION}/velero-${VERSION}-linux-amd64.tar.gz -o velero.tgz
  tar zxvf velero.tgz
  sudo install -m 755 velero-*/velero /usr/local/bin/velero
popd

### remove temporary directory ###
rm -rf ${TMPDIR}
}

setup_homedir() {
cat <<EOT >> ${HOME}/.bash_profile
eval "\$(kubectl completion bash)"
eval "\$(direnv hook bash)"
EOT

mkdir -p ${HOME}/workspace/scripts
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

### TKGI settings
export TKGI_VERSION="1.8.1"
export TKGI_API_HOST="api.run.\${ENV_NAME}.\${DOMAIN_NAME}"
EOT

cat <<EOT > ${HOME}/workspace/scripts/tkgi-login.sh
#!/bin/bash

### make temporary directory ###
TMPDIR=/tmp/\$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
mkdir -p \${TMPDIR}

set -exo pipefail

TKGI_VERSION=\${TKGI_VERSION:-"1.8.1"}
if [ ! -f /usr/local/bin/tkgi ]; then
  TKGI_CLI_FILEID=\$(pivnet product-files --product-slug='pivotal-container-service' --release-version=\$TKGI_VERSION --format json | jq '.[] | select(.name == "TKGI CLI - Linux") | .id')
  PKS_CLI_FILEID=\$(pivnet product-files --product-slug='pivotal-container-service' --release-version=\$TKGI_VERSION --format json | jq '.[] | select(.name == "PKS CLI - Linux") | .id')
  KUBECTL_CLI_FILEID=\$(pivnet product-files --product-slug='pivotal-container-service' --release-version=\$TKGI_VERSION --format json | jq '.[] | select(.name | startswith("Kubectl")) | select(.name | endswith("Linux")) | .id')
   
  pushd \${TMPDIR}
    pivnet download-product-files --product-slug='pivotal-container-service' --release-version=\$TKGI_VERSION --product-file-id=\$TKGI_CLI_FILEID
    pivnet download-product-files --product-slug='pivotal-container-service' --release-version=\$TKGI_VERSION --product-file-id=\$PKS_CLI_FILEID
    pivnet download-product-files --product-slug='pivotal-container-service' --release-version=\$TKGI_VERSION --product-file-id=\$KUBECTL_CLI_FILEID
    sudo install -m 755 tkgi-linux-amd64-* /usr/local/bin/tkgi
    sudo install -m 755 pks-linux-amd64-* /usr/local/bin/pks
    sudo install -m 755 kubectl-linux-amd64-* /usr/local/bin/kubectl
  popd
fi
rm -rf \${TMPDIR}
 
TKGI_API_HOST=\${TKGI_API_HOST:-"api.run.\${ENV_NAME}.\${DOMAIN_NAME}"}
TKGI_ADMIN_PASSWORD=\$(om credentials -p pivotal-container-service -c .properties.uaa_admin_password -f secret)
 
tkgi login -a \${TKGI_API_HOST} -k -u admin -p \${TKGI_ADMIN_PASSWORD}
EOT
chmod +x ${HOME}/workspace/scripts/tkgi-login.sh
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

3. save OpsManager SSH private key (manually)
=====
vim ~/workspace/.opsman_ssh_key
chmod 600 ~/workspace/.opsman_ssh_key
=====

4. (after TKGI install) install TKGI CLI and login TKGI
=====
cd ~/workspace
./scripts/tkgi-login.sh
=====

EOT
}

install
setup_homedir
conclusion
