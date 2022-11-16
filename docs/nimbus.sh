#!/bin/bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

if [ -z "$GITHUB_AUTH_CREDS" -o -z "$NEW_HOSTNAME" ] ; then
  echo "Please run this script with GITHUB_AUTH_CREDS and NEW_HOSTNAME," >&2
  echo "such as 'curl -skL https://pvtl.cc/nimbus-k3s.sh | GITHUB_AUTH_CREDS=**** NEW_HOSTNAME=nimbus?? bash'" >&2
exit 1
fi

echo "Please run 'curl -skL https://pvtl.cc/nimbus-k3s.sh | GITHUB_AUTH_CREDS=**** NEW_HOSTNAME=nimbus?? bash'" >&2
echo "or 'curl -skL https://pvtl.cc/nimbus-docker.sh | GITHUB_AUTH_CREDS=**** NEW_HOSTNAME=nimbus?? bash'" >&2
exit 1
