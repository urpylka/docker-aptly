# Copyright 2023-2025 Sergei Agibalov
# Copyright 2018-2020 Artem B. Smirnov
# Copyright 2018 Jon Azpiazu
# Copyright 2016 Bryan J. Hong
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM debian:bookworm-slim

LABEL maintainer="urpylka@gmail.com"

ARG DEBIAN_FRONTEND=noninteractive
ARG VER_APTLY

# Update APT repository & install packages
RUN set -eux; \
  apt -q update && apt dist-upgrade -y; \
  apt -y --no-install-recommends install \
    graphviz \
    supervisor \
    curl \
    apt-utils \
    gettext-base \
    bash-completion \
    gpg-agent \
    ca-certificates \
    rng-tools; \
  apt clean && apt autoclean && apt autoremove; \
  echo "if ! shopt -oq posix; then\n\
  if [ -f /usr/share/bash-completion/bash_completion ]; then\n\
    . /usr/share/bash-completion/bash_completion\n\
  elif [ -f /etc/bash_completion ]; then\n\
    . /etc/bash_completion\n\
  fi\n\
fi" >> /etc/bash.bashrc;

ENV GNUPGHOME="/opt/aptly/gpg" \
    NGINX_CLIENT_MAX_BODY_SIZE=100M

COPY [ "assets", "/tmp/assets" ]

# Install Aptly
RUN set -eux; \
  mkdir -p /etc/apt/keyrings && chmod 755 /etc/apt/keyrings; \
  curl -sL -o /etc/apt/keyrings/aptly.asc http://www.aptly.info/pubkey.txt; \
  echo "deb [signed-by=/etc/apt/keyrings/aptly.asc] http://repo.aptly.info/release bookworm main" >> /etc/apt/sources.list.d/aptly.list; \
  apt -q update && apt -y --no-install-recommends install aptly=${VER_APTLY} && apt clean; \
  rm -rf /var/lib/apt/lists/* \
    && mv /tmp/assets/aptly.conf /etc/aptly.conf \
    && mv /tmp/assets/supervisord.web.conf /etc/supervisor/conf.d/web.conf \
    && mv /tmp/assets/*.sh /opt/;

ADD https://raw.githubusercontent.com/aptly-dev/aptly/v${VER_APTLY}/completion.d/aptly /usr/share/bash-completion/completions/aptly

# Configure Nginx
RUN  set -eux; \
  apt -q update && apt -y install nginx && apt clean; \
  rm /etc/nginx/sites-enabled/* \
    && mkdir -p /etc/nginx/templates \
    && mv /tmp/assets/nginx.conf.template /etc/nginx/templates/default.conf.template \
    && rm -r /tmp/assets;

# Declare ports in use
EXPOSE 80 8080

ENTRYPOINT [ "/opt/entrypoint.sh" ]

# Start Supervisor when container starts (It calls nginx)
CMD /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf

WORKDIR /opt/aptly