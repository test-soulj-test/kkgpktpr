#!/bin/sh

if [ -n "${CI}" ]; then
  if ! which ssh-agent; then
    apt-get update -y && apt-get install openssh-client -y
  fi

  eval $(ssh-agent -s)

  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  cp config/known_hosts ~/.ssh/known_hosts
  chmod 644 ~/.ssh/known_hosts

  echo "$RELEASE_BOT_PRIVATE_KEY" | tr -d '\r' | ssh-add - > /dev/null
fi
