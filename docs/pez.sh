#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

install() {
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

  ### mosh, jq, direnv, OpenVPN, groff, netcat, bash-completion ###
  if [ ! -f /usr/bin/mosh ]; then
    echo "Installing APT packages..."
    sudo apt-get update
    sudo apt-get install -y mosh jq direnv openvpn groff netcat-openbsd bash-completion
  fi

  ### govc ###
  VERSION=$(curl -s https://api.github.com/repos/vmware/govmomi/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -LO https://github.com/vmware/govmomi/releases/download/v0.23.0/govc_linux_amd64.gz
    gunzip govc_linux_amd64.gz
    sudo install -m 755 ./govc_linux_amd64 /usr/local/bin/govc
  popd

  ### mc ###
  pushd ${TMPDIR}
    curl -LO https://dl.minio.io/client/mc/release/linux-amd64/mc -o ./mc
    sudo install -m 755 ./mc /usr/local/bin/
  popd

  ### kubectl ###
  pushd ${TMPDIR}
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl -o .//kubectl
    sudo install -m 755 ./kubectl /usr/local/bin/
  popd

  ### Helm 3 ###
  VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -vL https://get.helm.sh/helm-${VERSION}-linux-amd64.tar.gz -o helm.tgz
    tar zxvf helm.tgz linux-amd64/
    sudo install -m 755 linux-amd64/helm /usr/local/bin/helm
  popd

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

conclusion() {
cat <<EOT

########### setup completed ##########

you may do steps below:

1. enable direnv and kubectl bash-completion
=====
source ~/.bash_profile
=====

EOT
}

install
setup_homedir
conclusion
