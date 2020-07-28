#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

install() {
  set -euxo pipefail

  ### SSH via key ###
  if [ ! -f $HOME/.ssh/authorized_keys ]; then
    github_id="${GITHUB_ID:-kenojiri}"
    echo "Installing SSH public key..."
    ssh-import-id-gh $github_id
  fi

  ### mosh ###
  if [ ! -f /usr/bin/mosh ]; then
    echo "Installing mosh..."
    sudo apt-get update
    sudo apt-get install -y mosh
  fi

  ### OpenVPN ###
  if [ ! -f /usr/sbin/openvpn ]; then
    echo "Installing OpenVPN client..."
    sudo apt-get install -y openvpn
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

install
