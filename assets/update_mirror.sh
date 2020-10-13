#! /usr/bin/env bash
set -e

# Automate the initial creation and update of a mirror in aptly.
# Uncomment a prepared section or use your own.

# For any section you select, you need to install repo signing public
# key, if you wanna take it from your system you can look for in:
# /usr/share/keyrings/ (like /usr/share/keyrings/ubuntu-archive-keyring.gpg) or you can take it from apt-key (apt-key help / list / export).
# Export the key to the pubring in GPG utility (ususaly /root/.gnupg/pubring.gpg). You can use prepared script /opt/keys_imp.sh for it.

# The variables (as set below) will create a mirror of the Ubuntu Trusty repo
# with the main & universe components, you can add other components like restricted
# multiverse etc by adding to the array (separated by spaces).

# For more detail about each of the variables below refer to:
# https://help.ubuntu.com/community/Repositories/CommandLine

# UPSTREAM_URL="http://archive.ubuntu.com/ubuntu/"
# REPO=ubuntu
# OS_RELEASE=bionic
# DISTS=( ${OS_RELEASE} ${OS_RELEASE}-updates ${OS_RELEASE}-security )
# COMPONENTS=( main universe )
# ARCH=amd64

# The variables (as set below) will create a mirror of the Debian Buster repo
# with the main and update components. If you do mirror these, you'll want to
# include "deb http://security.debian.org buster/updates main" in your sources.list
# file or mirror it similarly as done below to keep up with security updates.

# UPSTREAM_URL="http://deb.debian.org/debian/"
# REPO=debian
# OS_RELEASE=buster
# DISTS=( ${OS_RELEASE} ${OS_RELEASE}-updates )
# COMPONENTS=( main )
# ARCH=amd64

# The variables (as set below) will create a mirror of the default Raspbian Buster
# repo (that is used in Raspbian images).

UPSTREAM_URL="http://raspbian.raspberrypi.org/raspbian/"
REPO=raspbian
DISTS=( buster )
COMPONENTS=( main contrib non-free rpi )
ARCH=armhf

# Create the mirror repository, if it doesn't exist
set +e
for dist in ${DISTS[@]}; do
  aptly mirror list -raw | grep "^${REPO}-${dist}$"
  if [[ $? -ne 0 ]]; then
    echo "Creating mirror of ${REPO} repository."
    aptly mirror create \
      -architectures=${ARCH} ${REPO}-${dist} ${UPSTREAM_URL} ${dist} ${COMPONENTS[@]}
  fi
done
set -e

# Update the all repository mirrors
for dist in ${DISTS[@]}; do
  echo "Updating ${REPO} repository mirror.."
  aptly mirror update ${REPO}-${dist}
done

# Create snapshots of updated repositories
for dist in ${DISTS[@]}; do
  echo "Creating snapshot of ${REPO}-${dist} repository mirror.."
  SNAPSHOT=${REPO}-${dist}-`date +%s%N`
  SNAPSHOTARRAY+="${SNAPSHOT} "
  aptly snapshot create ${SNAPSHOT} from mirror ${REPO}-${dist}
done

echo "Snapshots results:"
echo ${SNAPSHOTARRAY[@]}

# # Merge snapshots into a single snapshot with updates applied
# REPO_MERGED=${REPO}-merged-`date +%s%N`
# echo "Merging snapshots into one.."
# aptly snapshot merge -latest ${REPO_MERGED} ${SNAPSHOTARRAY[@]}

echo -n "Enter GPG passphrase:"
read -s GPG_PASSPHRASE
echo

# Publish the latest snapshots
set +e
for snap in ${SNAPSHOTARRAY[@]}; do
  snap_name=$(echo ${snap} | awk -F'-' '{print $1" "$2}')
  dist=$(echo ${snap_name} | awk '{print $2}')
  aptly publish list -raw | grep "^${snap_name}$"
  if [[ $? -eq 0 ]]; then
    aptly publish switch -passphrase="${GPG_PASSPHRASE}" ${dist} ${REPO} ${snap}
  else
    # Keys must be before name of a snapshot
    # -distribution=${REPO_MERGED} - it can be missed
    aptly publish snapshot -passphrase="${GPG_PASSPHRASE}" ${snap} ${REPO}
  fi
done
set -e

# Export the all GPG Public keys
if [[ ! -f /opt/aptly/public/repo_signing.key ]]; then
  gpg --export --armor > /opt/aptly/public/repo_signing.key
fi

# Generate Aptly Graph
aptly graph -output /opt/aptly/public/aptly_graph.png
