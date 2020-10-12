#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

common_install() {
  ### make temporary directory ###
  TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  mkdir -p ${TMPDIR}

  set -euxo pipefail

  ### SSH via key ###
  if [ ! -f $HOME/.ssh/authorized_keys ] || ! grep -q ssh-import-id $HOME/.ssh/authorized_keys ; then
    github_id="${GITHUB_ID:-kenojiri}"
    echo "Installing SSH public key..."
    ssh-import-id-gh $github_id
  fi

  ### deb packages ###
  echo "Installing deb packages..."
  sudo apt-get update
  sudo apt-get install -y \
    tmux jq direnv unzip groff netcat-openbsd bash-completion \
    apt-transport-https gnupg software-properties-common

  ### minio CLI (mc) ###
  pushd ${TMPDIR}
    curl -LO https://dl.minio.io/client/mc/release/linux-amd64/mc -o ./mc
    sudo install -m 755 ./mc /usr/local/bin/
  popd

  ### kubectl ###
  pushd ${TMPDIR}
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl -o ./kubectl
    sudo install -m 755 ./kubectl /usr/local/bin/
  popd

  ### Helm ###
  VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -vL https://get.helm.sh/helm-${VERSION}-linux-amd64.tar.gz -o helm.tgz
    tar zxvf helm.tgz linux-amd64/
    sudo install -m 755 linux-amd64/helm /usr/local/bin/helm
  popd

  ### Velero ###
  VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -vL https://github.com/vmware-tanzu/velero/releases/download/${VERSION}/velero-${VERSION}-linux-amd64.tar.gz -o velero.tgz
    tar zxvf velero.tgz
    sudo install -m 755 velero-*/velero /usr/local/bin/velero
  popd

  ### k14s (ytt, kbld, kapp, imgpkg, vendir, kwt, and etc.) ###
  curl -vL https://k14s.io/install.sh | sudo bash

  ### yj ###
  VERSION=$(curl -s https://api.github.com/repos/sclevine/yj/releases/latest | jq -r .tag_name) &&\
  pushd ${TMPDIR}
    curl -vL https://github.com/sclevine/yj/releases/download/${VERSION}/yj-linux -o ./yj &&\
    sudo install -m 755 yj /usr/local/bin/
  popd

  ### Cloud Foundry CLI (cf) ###
  wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
  echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list
  sudo apt-get update
  sudo apt-get install -y cf-cli
  sudo curl -vL https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf -o /usr/share/bash-completion/completions/cf

  ### bosh ###
  VERSION=$(curl -s https://api.github.com/repos/cloudfoundry/bosh-cli/releases/latest | jq -r .name | tr -d 'v')
  pushd ${TMPDIR}
    curl -vL https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${VERSION}-linux-amd64 -o ./bosh
    sudo install -m 755 ./bosh /usr/local/bin/
  popd

  ### Ops Manager CLI (om) ###
  VERSION=$(curl -s https://api.github.com/repos/pivotal-cf/om/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -vL https://github.com/pivotal-cf/om/releases/download/${VERSION}/om-linux-${VERSION} -o ./om
    sudo install -m 755 ./om /usr/local/bin/
  popd

  ### VMware Tanzu Network CLI (pivnet) ###
  VERSION=$(curl -s https://api.github.com/repos/pivotal-cf/pivnet-cli/releases/latest | jq -r .tag_name | sed 's/v//')
  pushd ${TMPDIR}
    curl -vL https://github.com/pivotal-cf/pivnet-cli/releases/download/v${VERSION}/pivnet-linux-amd64-${VERSION} -o ./pivnet
    sudo install -m 755 ./pivnet /usr/local/bin/
  popd

  ### BOSH Backup and Restore CLI (bbr) ###
  VERSION=$(curl -s https://api.github.com/repos/cloudfoundry-incubator/bosh-backup-and-restore/releases/latest | jq -r .tag_name | sed 's/v//')
  pushd ${TMPDIR}
    curl -vL https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/download/${VERSION}/bbr-${VERSION}-linux-amd64 -o ./bbr
    sudo install -m 755 ./bbr /usr/local/bin/
  popd

  ### CredHub CLI ###
  VERSION=$(curl -s https://api.github.com/repos/cloudfoundry-incubator/credhub-cli/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -vL https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/${VERSION}/credhub-linux-${VERSION}.tgz | tar zxvf -
    sudo install -m 755 ./credhub /usr/local/bin/
  popd

  ### HashiCorp Terraform ###
  VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r .tag_name | sed 's/v//')
  curl -vL https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_linux_amd64.zip -o ${TMPDIR}/terraform.zip
  cd /usr/local/bin
  sudo unzip -u ${TMPDIR}/terraform.zip

  ### remove temporary directory ###
  rm -rf ${TMPDIR}
}

common_install_docker() {
  curl -sSL https://get.docker.com/ | sudo sh
  sudo usermod -aG docker $(id -un)
  apt-get install -y docker-compose
}

common_setup_homedir() {
  ### bash ###
  if [ ! -f $HOME/.bash_profile ] || ! grep -q kubectl $HOME/.bash_profile ; then
    echo "Setting .bash_profile..."
    cat <<EOT >> ${HOME}/.bash_profile
eval "\$(kubectl completion bash)"
eval "\$(direnv hook bash)"
EOT
  fi

  ### tmux ###
  if [ ! -f $HOME/.tmux.conf ]; then
    echo "Setting tmux..."
    cat <<EOF > $HOME/.tmux.conf
set -g prefix C-z
unbind C-b
set -sg escape-time 1
set -g base-index 1
setw -g pane-base-index 1
bind C-z send-prefix
bind | split-window -h
bind - split-window -v
set -g default-terminal "screen-256color"
set -g status-fg white
set -g status-bg black
setw -g window-status-fg cyan
setw -g window-status-bg default
setw -g window-status-attr dim
setw -g window-status-current-fg white
setw -g window-status-current-bg red
setw -g window-status-current-attr bright
set -g pane-border-fg green
set -g pane-border-bg black
set -g pane-active-border-fg white
set -g pane-active-border-bg yellow
set -g message-fg white
set -g message-bg black
set -g message-attr bright
set -g status-left "#[fg=green]@#H "
set-option -g status-left-length 15
set -g status-right "#[fg=green] %m/%d(%a)%H:%M"
set -g status-interval 60
setw -g monitor-activity on
set -g visual-activity on
set -g status-style "bg=colour22"
setw -g mode-keys vi
bind Space next-window
bind h previous-window
set-option -g renumber-windows on
bind [ copy-mode
bind ] paste-buffer
if-shell "which xsel" '\
  bind-key -t vi-copy y copy-pipe "xsel -ib"; \
  bind-key -t vi-copy enter copy-pipe "xsel -ib"; \
'
bind C-c new-window
EOF
  fi
}