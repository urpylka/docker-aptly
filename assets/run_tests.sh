#! /usr/bin/env bash

# Copyright 2018-2020 Artem Smirnov <urpylka@gmail.com>
# Licensed under the Apache License, Version 2.0

# Start Supervisor when container starts (He calls nginx and Aptly API)
/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf &
sleep 4

# Generate GPG keys
/opt/keys_gen.sh "Artem Smirnov" "urpylka@gmail.com" "password"

# Generate htpasswd file
/opt/gen_htpasswd.sh admin passwd

echo2() {
    # TEMPLATE: echo_stamp <TEXT> <COLOR> <LINE_BREAK>
    # More info there https://www.shellhacks.com/ru/bash-colors/

    TEXT=$1
    # TEXT="$(date '+[%Y-%m-%d %H:%M:%S]') ${TEXT}"

    TEXT="\e[1m$TEXT\e[0m" # BOLD

    case "$2" in
        GREEN) TEXT="\e[32m${TEXT}\e[0m";;
        RED)   TEXT="\e[31m${TEXT}\e[0m";;
        BLUE)  TEXT="\e[34m${TEXT}\e[0m";;
    esac

    [[ -z $3 ]] \
        && { echo -e ${TEXT}; } \
        || { echo -ne ${TEXT}; }
}

RESP1=`curl -I --max-time 2 http://localhost:80 2>/dev/null`

[[ ! -z ${RESP1} ]] \
    && { echo2 "Host is up" "GREEN"; } \
    || { echo2 "Error: Host is down" "RED"; exit 1; }


RESP2=`curl -I --max-time 2 http://localhost:80/repo_signing.key 2>/dev/null`

[[ $(echo ${RESP2} | grep "HTTP/1.1 200 OK") ]] \
    && { echo2 "The file exists" "GREEN"; } \
    || { echo2 "Error: Bad response from the file" "RED"; exit 1; }

[[ $(echo ${RESP2} | grep Content-Length | awk -F ': ' '{print $2}') > 2000 ]] \
    && { echo2 "The filesize is ok" "GREEN"; } \
    || { echo2 "Error: The filesize is too small" "RED"; exit 1; }


RESP3=`curl http://localhost:8080/api/version 2>/dev/null`

[[ $(echo ${RESP3} | grep "Version") ]] \
    && { echo2 "Aptly is ${RESP3}" "GREEN"; } \
    || { echo2 "Failed to connect to the Aptly API" "RED"; exit 1; }


RESP4=`curl http://localhost:80/api/version 2>/dev/null`

[[ $(echo ${RESP4} | grep "401 Authorization Required") ]] \
    && { echo2 "Aptly API is on the proxy server & password guard is working" "GREEN"; } \
    || { echo2 "Aptly API doesn't respond at the proxy server or password guard doesn't work" "RED"; exit 1; }


RESP5=`curl -u admin:passwd http://localhost:80/api/version 2>/dev/null`

[[ $(echo ${RESP5} | grep "Version") ]] \
    && { echo2 "Authentification is complete" "GREEN"; } \
    || { echo2 "Authentification failed" "RED"; exit 1; }

# Check repo
curl -u admin:passwd http://localhost:80/api/repos
# []

# Create the repo
curl -u admin:passwd -X POST -H 'Content-Type: application/json' --data '{"Name": "general", "DefaultDistribution":"", "DefaultComponent":""}' http://localhost:80/api/repos
# {"Name":"general","Comment":"","DefaultDistribution":"","DefaultComponent":""}

# Upload the test package
curl -u admin:passwd -F file=@assets/aptly_1.4.0_amd64.deb http://localhost:80/api/files/aptly_1.4.0
# ["aptly_1.4.0/aptly_1.4.0_amd64.deb"]

# Show the uploaded package
curl -u admin:passwd http://localhost:80/api/files
# ["aptly_1.4.0"]

# Add the test package to the repo
curl -u admin:passwd -X POST http://localhost:80/api/repos/general/file/aptly_1.4.0
# {"FailedFiles":[],"Report":{"Warnings":[],"Added":["aptly_1.4.0_amd64 added"],"Removed":[]}}

# Check the package
curl -u admin:passwd http://localhost:80/api/repos/general/packages
# ["Pamd64 aptly 1.4.0 a226665b7c8a86f"]

# Publish the repo
# If /api/publish/<general> is skipped it will be placed in root
curl -u admin:passwd -X POST -H 'Content-Type: application/json' --data '{"Distribution": "wheezy", "SourceKind": "local", "Sources": [{"Name": "general"}], "Signing": {"Skip": false, "Passphrase": "password", "SecretKeyring": "/opt/aptly/gpg/pubring.kbx"}}' http://localhost:80/api/publish/general3
# {"AcquireByHash":false,"Architectures":["amd64"],"ButAutomaticUpgrades":"","Distribution":"wheezy","Label":"","NotAutomatic":"","Origin":"","Prefix":"general","SkipContents":false,"SourceKind":"local","Sources":[{"Component":"main","Name":"general"}],"Storage":""}

# https://github.com/aptly-dev/aptly/issues/689#issuecomment-354120842
# aptly publish repo -distribution="amd64" general general
# aptly publish repo -distribution="amd64" -passphrase="Password" general general
# {"error":"unable to publish: unable to detached sign file: exit status 2"}

# Download & install the key
curl -O http://localhost:80/repo_signing.key
apt-key add repo_signing.key

# Update lists
cp /etc/apt/sources.list /etc/apt/sources.list.bak
echo "deb http://localhost:80/ ubuntu main" > /etc/apt/sources.list
apt-get update

# Download the test package & check hashsum
# https://codebeer.ru/skachat-paket-iz-repozitoriya-debian/
apt download aptly
# checkhash
