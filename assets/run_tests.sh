#! /usr/bin/env bash

# Copyright 2018-2020 Artem Smirnov <urpylka@gmail.com>
# Licensed under the Apache License, Version 2.0

# Start Supervisor when container starts (He calls nginx and Aptly API)
/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf &
sleep 4

# Generate GPG keys
/opt/keys_gen.sh "First Last" "your@email.com" "Password"

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
