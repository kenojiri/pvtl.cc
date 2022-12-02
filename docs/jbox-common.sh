#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

if test -z "$GITHUB_AUTH_CREDS"; then
  export CURL=curl
else
  export CURL="curl -k -u ${GITHUB_AUTH_CREDS}"
fi

common_install() {
  ### make temporary directory ###
  TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  mkdir -p ${TMPDIR}

  ### deb packages ###
  echo "Installing deb packages..."
  sudo apt-get update
  sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confnew" \
    git mosh tmux jq direnv unzip groff netcat-openbsd bash-completion sshpass \
    apt-transport-https gnupg software-properties-common"

  ### starship ###
  curl -sS https://starship.rs/install.sh | sh

  ### yj ###
  VERSION=$(${CURL} -s https://api.github.com/repos/sclevine/yj/releases/latest | jq -r .tag_name) &&\
  pushd ${TMPDIR}
    curl -vL https://github.com/sclevine/yj/releases/download/${VERSION}/yj-linux -o ./yj &&\
    sudo install -m 755 yj /usr/local/bin/
  popd

  ### minio CLI (mc) ###
  pushd ${TMPDIR}
    curl -LO https://dl.minio.io/client/mc/release/linux-amd64/mc -o ./mc
    sudo install -m 755 ./mc /usr/local/bin/
  popd

  ### lego ###
  VERSION=$(${CURL} -s https://api.github.com/repos/go-acme/lego/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -vL https://github.com/go-acme/lego/releases/download/${VERSION}/lego_${VERSION}_linux_amd64.tar.gz -o lego.tgz
    tar zxvf lego.tgz
    sudo install -m 755 lego /usr/local/bin/lego
  popd

  ### bosh ###
  VERSION=$(${CURL} -s https://api.github.com/repos/cloudfoundry/bosh-cli/releases/latest | jq -r .name | tr -d 'v')
  pushd ${TMPDIR}
    curl -vL https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${VERSION}-linux-amd64 -o ./bosh
    sudo install -m 755 ./bosh /usr/local/bin/
  popd

  ### Ops Manager CLI (om) ###
  VERSION=$(${CURL} -s https://api.github.com/repos/pivotal-cf/om/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -vL https://github.com/pivotal-cf/om/releases/download/${VERSION}/om-linux-${VERSION} -o ./om
    sudo install -m 755 ./om /usr/local/bin/
  popd

  ### VMware Tanzu Network CLI (pivnet) ###
  VERSION=$(${CURL} -s https://api.github.com/repos/pivotal-cf/pivnet-cli/releases/latest | jq -r .tag_name | sed 's/v//')
  pushd ${TMPDIR}
    curl -vL https://github.com/pivotal-cf/pivnet-cli/releases/download/v${VERSION}/pivnet-linux-amd64-${VERSION} -o ./pivnet
    sudo install -m 755 ./pivnet /usr/local/bin/
  popd

  ### BOSH Backup and Restore CLI (bbr) ###
  VERSION=$(${CURL} -s https://api.github.com/repos/cloudfoundry/bosh-backup-and-restore/releases/latest | jq -r .tag_name | sed 's/v//')
  pushd ${TMPDIR}
    curl -vL https://github.com/cloudfoundry/bosh-backup-and-restore/releases/download/v${VERSION}/bbr-${VERSION}-linux-amd64 -o ./bbr
    sudo install -m 755 ./bbr /usr/local/bin/
  popd

  ### CredHub CLI ###
  VERSION=$(${CURL} -s https://api.github.com/repos/cloudfoundry/credhub-cli/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -vL https://github.com/cloudfoundry/credhub-cli/releases/download/${VERSION}/credhub-linux-${VERSION}.tgz | tar zxvf -
    sudo install -m 755 ./credhub /usr/local/bin/
  popd

  ### HashiCorp Terraform ###
  VERSION=$(${CURL} -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r .tag_name | sed 's/v//')
  curl -vL https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_linux_amd64.zip -o ${TMPDIR}/terraform.zip
  cd /usr/local/bin
  sudo unzip -u ${TMPDIR}/terraform.zip

  ### HashiCorp Vault ###
  VERSION=$(${CURL} -s https://api.github.com/repos/hashicorp/vault/releases/latest | jq -r .tag_name | sed 's/v//')
  curl -vL https://releases.hashicorp.com/vault/${VERSION}/vault_${VERSION}_linux_amd64.zip -o ${TMPDIR}/vault.zip
  cd /usr/local/bin
  sudo unzip -u ${TMPDIR}/vault.zip

  ### remove temporary directory ###
  rm -rf ${TMPDIR}
}

common_install_kubectl() {
  ### make temporary directory ###
  TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  mkdir -p ${TMPDIR}


  ### remove temporary directory ###
  rm -rf ${TMPDIR}
}

common_install_k8s_accessories() {
  ### make temporary directory ###
  TMPDIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  mkdir -p ${TMPDIR}

  ### Carvel (ytt, kbld, kapp, imgpkg, vendir, kwt, and etc.) ###
  curl -vL https://carvel.dev/install.sh | sudo bash

  ### krew and kubectl plugins ###
  VERSION=$(${CURL} -s https://api.github.com/repos/kubernetes-sigs/krew/releases/latest | jq -r .tag_name) &&\
  pushd ${TMPDIR}
    wget https://github.com/kubernetes-sigs/krew/releases/download/${VERSION}/krew-linux_amd64.tar.gz
    tar zxvf krew-linux_amd64.tar.gz ./krew-linux_amd64
    sudo install krew-linux_amd64 /usr/local/bin/krew
  popd

  ### Helm ###
  VERSION=$(${CURL} -s https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -vL https://get.helm.sh/helm-${VERSION}-linux-amd64.tar.gz -o helm.tgz
    tar zxvf helm.tgz linux-amd64/
    sudo install -m 755 linux-amd64/helm /usr/local/bin/helm
  popd

  ### Velero ###
  VERSION=$(${CURL} -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | jq -r .tag_name)
  pushd ${TMPDIR}
    curl -vL https://github.com/vmware-tanzu/velero/releases/download/${VERSION}/velero-${VERSION}-linux-amd64.tar.gz -o velero.tgz
    tar zxvf velero.tgz
    sudo install -m 755 velero-*/velero /usr/local/bin/velero
  popd

  ### remove temporary directory ###
  rm -rf ${TMPDIR}
}

common_install_docker() {
  curl -sSL https://get.docker.com/ | sudo sh
  sudo usermod -aG docker $(id -un)
  cat <<EOT >> ${HOME}/.bash_profile
alias docker-compose=docker compose
EOT
}

common_install_k3s_master() {
  curl -sfL https://get.k3s.io | sudo sh -s - --write-kubeconfig-mode 644
  sudo chmod 755 /var/lib/rancher/k3s/server/cred
  sudo chmod 755 /var/lib/rancher/k3s/server/tls
  sudo chmod 644 /var/lib/rancher/k3s/server/tls/*

  cat <<EOT >> ${HOME}/.bash_profile
eval "\$(kubectl completion bash)"
alias k=kubectl
complete -o default -F __start_kubectl k
EOT
}

common_setup_homedir() {
  ### starship ###
  cat <<EOT >> ${HOME}/.starship.toml
"\$schema" = 'https://starship.rs/config-schema.json'
format = "\$username\$hostname\$directory\$all"
[character]
success_symbol = "[➜](bold green)"
[username]
format = "[\$user](\$style)@"
style_user = "bold white"
[hostname]
ssh_symbol = ""
format = "[\$ssh_symbol\$hostname](\$style):"
style = "bold dimmed white"
[directory]
truncation_length = 5
truncate_to_repo = false
truncation_symbol = "…/"
style = "bold dimmed white"
[git_branch]
symbol = ""
format = "[\$symbol\$branch(:\$remote_branch)](\$style) "
[kubernetes]
disabled = false
symbol = "☸"
format = '[\$symbol\$context(\\(\$namespace\\))](\$style) '
style = "blue bold"
EOT

  ### tmux ###
  cat <<EOT > ${HOME}/.tmux.conf
set-option -g default-terminal "xterm-256color"
set-option -ga terminal-overrides ',*256color:Tc'

set-option -sg escape-time 1
set-option -g base-index 1

set-option -g status-position bottom
set-option -g status-style fg=black,bg=colour24
set-option -g status-left '#[fg=cyan]#{?client_prefix,#[reverse],}#H #[default]'
set-option -g status-left-length 15
set-option -g status-right '#[fg=cyan] [#S]'
set-option -g renumber-windows on
set-option -g window-status-style fg=black
set-option -g window-status-current-style fg=white,bg=black,bright
set-option -g message-style fg=white,bg=black,bright
                                                                                
set-option -g mode-keys vi
set-option -g prefix C-z
unbind C-b

bind Space next-window
bind h previous-window
bind c new-window -c "#{pane_current_path}"
bind C-c new-window -c "#{pane_current_path}"
bind [ copy-mode
bind ] paste-buffer
                    
bind -r w if "tmux display -p \"#{session_windows}\" | grep ^1\$ && tmux display -p \"#{window_panes}\" | grep ^1\$" \
    "confirm-before -p \"Kill the only pane in the only window? It will kill this session too. (y/n)\" kill-pane" \
        "kill-pane"
EOT

  ### bash ###
  cat <<EOT >> ${HOME}/.bash_profile
export STARSHIP_CONFIG=\${HOME}/.starship.toml
eval "\$(starship init bash)"
eval "\$(direnv hook bash)"
printf "\\033k\$(hostname -s)\\033\\\\"
EOT
}

common_add_ssh_pubkey() {
  if [ ! -f $HOME/.ssh/authorized_keys ] ; then
    github_id="${GITHUB_ID:-kenojiri}"
    mkdir -p $HOME/.ssh
    ${CURL} -s https://github.com/${github_id}.keys -o $HOME/.ssh/authorized_keys
  fi
}
