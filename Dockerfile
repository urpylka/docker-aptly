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

FROM debian:buster

LABEL maintainer="urpylka@gmail.com"

ARG DEBIAN_FRONTEND=noninteractive

# Update APT repository & install packages (except aptly)
RUN apt-get -q update \
  && apt-get -y install \
    bzip2 \
    gnupg2 \
    gpgv \
    graphviz \
    supervisor \
    nginx \
    curl \
    xz-utils \
    apt-utils \
    bash-completion

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ED75B5A4483DA07C \
  && echo "deb http://repo.aptly.info/ squeeze main" >> /etc/apt/sources.list

# Install aptly package
RUN apt-get -q update \
  && apt-get -y install aptly=1.4.0 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Configure Nginx
RUN rm /etc/nginx/sites-enabled/*

# Create volume
VOLUME [ "/opt/aptly" ]
ENV GNUPGHOME="/opt/aptly/gpg"

# Install configurations
COPY assets/aptly.conf /etc/aptly.conf
COPY assets/nginx.conf /etc/nginx/conf.d/default.conf
COPY assets/supervisord.web.conf /etc/supervisor/conf.d/web.conf

# Install scripts
COPY assets/*.sh /opt/

ADD https://raw.githubusercontent.com/aptly-dev/aptly/v1.4.0/completion.d/aptly /usr/share/bash-completion/completions/aptly

RUN echo "if ! shopt -oq posix; then\n\
  if [ -f /usr/share/bash-completion/bash_completion ]; then\n\
    . /usr/share/bash-completion/bash_completion\n\
  elif [ -f /etc/bash_completion ]; then\n\
    . /etc/bash_completion\n\
  fi\n\
fi" >> /etc/bash.bashrc

# Declare ports in use
EXPOSE 80 8080

# Start Supervisor when container starts (It calls nginx)
CMD /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf

WORKDIR /opt/aptly
