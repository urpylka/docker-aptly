#! /usr/bin/env bash

# Copyright 2018-2020 Artem B. Smirnov
# Licensed under the Apache License, Version 2.0

# Use: keys_gen.sh <FULL_NAME> <EMAIL_ADDRESS> <GPG_PASSPHRASE>

# https://stackoverflow.com/questions/4437573/bash-assign-default-value
: ${FULL_NAME:=${1}}
: ${EMAIL_ADDRESS:=${2}}
: ${GPG_PASSPHRASE:=${3}}

[[ -z ${FULL_NAME} ]] && { echo "FULL_NAME wasn't specified"; exit 1; }
[[ -z ${EMAIL_ADDRESS} ]] && { echo "EMAIL_ADDRESS wasn't specified"; exit 1; }
[[ -z ${GPG_PASSPHRASE} ]] && { echo "GPG_PASSPHRASE wasn't specified"; exit 1; }

# If the repository GPG keypair doesn't exist, create it.
if [[ ! -d /opt/aptly/gpg/private-keys-v1.d/ ]] || [[ ! -f /opt/aptly/gpg/pubring.kbx ]]; then
  echo "Generating the new GPG keypair"
  rngd -r /dev/urandom

  mkdir -p ${GNUPGHOME}
  chmod 700 ${GNUPGHOME}

  # If your system doesn't have a lot of entropy this may, take a long time
  # Google how-to create "artificial" entropy, if this gets stuck
  gpg --batch --passphrase "${GPG_PASSPHRASE}" --quick-gen-key "${FULL_NAME} <${EMAIL_ADDRESS}>" default default 0
else
  echo "No need to generate the new GPG keypair"
fi

# If the repository public key doesn't exist, export it.
if [[ ! -d /opt/aptly/public ]] ||
   [[ ! -f /opt/aptly/public/repo_signing.key ]] ||
   [[ ! -f /opt/aptly/public/repo_signing.gpg ]]; then
  echo "Export the GPG public keys"
  mkdir -p /opt/aptly/public
  # Export only all public keys,
  # for export private keys use --export-secret-keys
  gpg --export --armor > /opt/aptly/public/repo_signing.key
  gpg --export > /opt/aptly/public/repo_signing.gpg
else
  echo "No need to export the GPG keys"
fi
