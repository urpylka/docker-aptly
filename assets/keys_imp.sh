#! /usr/bin/env bash

# Copyright 2018-2020 Artem B. Smirnov
# Copyright 2018 Jon Azpiazu
# Copyright 2016 Bryan J. Hong
# Licensed under the Apache License, Version 2.0

# Use: keys_imp.sh <path-to-keyring.gpg>

# Import keyrings if they exist
if [[ -f ${1} ]]; then
  # Export all public keys from a keyring or a key
  # ${1} to $GNUPGHOME/trustedkeys.gpg

  I=${1}

  # gpg2 --no-options --no-default-keyring --keyring trustedkeys.gpg  --keyserver pool.sks-keyservers.net --recv-keys 9D6D8F6BC857C906 AA8E81B4331F7F50
  # wget -O - http://repo.coex.space/aptly_repo_signing.key | \
  # gpg2 --no-options --no-default-keyring --keyring trustedkeys.gpg  --import

  gpg2 --no-options --no-default-keyring --keyring ${I} --export | \
  gpg2 --no-options --no-default-keyring --keyring trustedkeys.gpg  --import

  # gpg2 --no-options --no-default-keyring --keyring trustedkeys.gpg  --list-keys
fi