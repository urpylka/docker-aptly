# docker-aptly

![container diagram](/docs/aptly.png)

**aptly** is a swiss army knife for Debian repository management: it allows you to mirror remote repositories, manage local package repositories, take snapshots, pull new versions of packages along with dependencies, publish as Debian repository. More info are on [aptly.info](http://aptly.info) and on [github](https://github.com/aptly-dev/aptly).

**nginx** is an HTTP and reverse proxy server, a mail proxy server, and a generic TCP proxy server, originally written by Igor Sysoev. More info is on [nginx.org](http://nginx.org/en/).

## Quickstart

1. Create docker `aptly-data` volume **if it doesn't exist**, otherwise use directory:

    ```bash
    docker volume create --name aptly-data
    ```

    Also you can use `--driver` option. By default it equals to `local`. More info is [here](https://docs.docker.com/engine/extend/legacy_plugins/#volume-plugins#volume-plugins).

    All of aptly's data (including GPG keyrings) is bind mounted outside of the container to preserve it if the container is removed or rebuilt.

2. If you want to customize image or build the container locally, **check out this repository and build, otherwise skip this step** and use prepared image from [`DockerHub`](https://hub.docker.com/r/urpylka/aptly):

    ```bash
    git clone https://github.com/urpylka/docker-aptly.git
    docker build docker-aptly --tag urpylka/aptly:latest
    ```

    If you decide build own I suggest you use [`docker-compose`](#manage-locally) commands. It will build own image before use.

3. Then **generate keypair**. It won't regenerate that, if you already have keypair (if a keyring exist at `aptly-data`):

    ```bash
    docker run --rm --log-driver=none \
      --volume aptly-data:/opt/aptly \
      urpylka/aptly:latest \
      /opt/keys_gen.sh "First Last" "your@email.com" "Password"
    ```

    `"First Last" "your@email.com" "Password"` will be associated with the GPG apt signing key.

    Keep in the mind that the GPG passphrase using ONLY BY USERS (at the external container) for:

    1. Generating GPG keys (In the temporary container)
    2. Singing Aptly packages (using CLI tool or REST API)

    Keep your GPG passphrase separately from the GPG keypair (keyrings).

4. **Run `aptly` and `nginx`**

    ```bash
    docker run \
      --detach=true \
      --log-driver=syslog \
      --restart=always \
      --name="aptly" \
      --publish 80:80 \
      --volume aptly-data:/opt/aptly \
      urpylka/aptly:latest
    ```

    If it returned (usualy on macOS):

    > docker: Error response from daemon: failed to initialize logging driver: Unix syslog delivery error.

    Probably you haven't some driver. Execute `docker rm aptly` and try again without `--log-driver=syslog`.

    Flag | Explanation
    --- | ---
    `--detach=true` | Run the container in the background
    `--log-driver=syslog` | Send nginx logs to syslog on the Docker host  (requires Docker 1.6 or higher), more info is [here](https://docs.docker.com/config/containers/logging/configure/#supported-logging-drivers).
    `--restart=always` | Automatically start the container when the Docker daemon starts
    `--name="aptly"` | Name of the container
    `--volume aptly-data:/opt/aptly` | Path (if you want set path use absolute path) or volume's name that aptly will use to store his data : mapped path in the container
    `--publish 80:80` | Docker host port : mapped port in the container
    `--network="some-nw"` | Attach a docker container to some network
    `--rm` | Remove a docker container when it will be stopped

5. **Next steps**

    * You can manage docker container with docker or [`docker-compose`](#manage-locally). For example:

        ```bash
        docker start aptly
        docker restart aptly
        docker stop aptly
        docker rm aptly
        ```

    * Use `docker volume` to manage the created volume.

    * **Configure your own debian-repository.** See [here](#configure-the-repository).

        You can also use [Aptly REST API](https://www.aptly.info/doc/api/) at `YOUR-HOST/api`. You need to generate `htpasswd` file before.

        ```bash
        docker run --rm --log-driver=none \
          --volume aptly-data:/opt/aptly \
          urpylka/aptly:latest \
          /opt/gen_htpasswd.sh "admin" "passwd"
        ```

        After executing:

        ```bash
        curl -u admin:passwd http://YOUR-HOST/api/version
        ```

        **Security:** Please note using http is not safety (your password sends as plain text). Add mandatory SSL encryption for `/api` via proxy server fe nginx. See [here](https://morph027.gitlab.io/post/protect-aptly-api-with-basic-authentication/).

    * **Configure a mirror of some repo.** See [here](#configure-the-mirror).

    * **Configure clients.** See [here](#setup-a-client-for-use-your-repo).

## Manage locally

If you want to build and run locally I suggest use `docker-compose`. But before create volume and generate keypair.

By default, Docker will map port 80 on the Docker host to port 80 within the container where nginx is configured to listen. You can change the external listening port to map to any port you like. Change the docker-compose file if you use him.

```bash
git clone https://github.com/urpylka/docker-aptly
cd docker-aptly/

# Build and run
# `--build` - if rebuild is requiring
# `-d` - run container in the background
# More info at: `docker-compose up --help`
docker-compose up -d --build

# Stop & remove (it doesn't remove created volumes)
docker-compose down

# Start / restart / stop container
docker-compose start
docker-compose restart
docker-compose stop

# If you want to test code with run_test.sh, use:
docker-compose --file docker-compose.test.yml build
docker-compose --file docker-compose.test.yml run sut
```

### Troubleshooting w same container name

May be conflict if you already pull aptly from docker hub:

> ERROR: for aptly  Cannot create container for service aptly: Conflict. The container name "/aptly" is already in use by container "85de5904f6fc73c04f4f8e7d08a09a1a63c2ba28afb5ce45aa9578ebdefeadc7". You have to remove (or rename) that container to be able to reuse that name.

In this situation you need remove currently aptly container (or rename it):

```bash
docker rm 85de5904f6fc73c04f4f8e7d08a09a1a63c2ba28afb5ce45aa9578ebdefeadc7
```

## Setup a client for use your repo

1. Fetch the public GPG key from your aptly repository and add it to your trusted repositories

    ```bash
    wget http://YOUR_HOST_FOR_APTLY/repo_signing.key
    apt-key add repo_signing.key
    ```

2. Backup then replace /etc/apt/sources.list

    ```bash
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    echo "deb http://YOUR_HOST_FOR_APTLY/ ubuntu main" > /etc/apt/sources.list
    apt-get update
    ```

    > `ubuntu` & `main` may be another. It's require from your repos on aptly.

## Configure the repository

1. **Copy files to volume.** First of all start docker container, because access to volume produced through him. Copy files to container (volume) directory, use [`docker cp`](https://docs.docker.com/engine/reference/commandline/cp/):

    ```bash
    docker cp aptly:/opt/aptly/<SRC_PATH> <DEST_PATH>
    docker cp <SRC_PATH> aptly:/opt/aptly/<DEST_PATH>
    ```

2. **Create and update debian-repo:**

    ```bash
    # Attach container
    docker exec -it aptly /bin/bash
    ```

    ```bash
    # Create repository folder
    aptly repo create -comment="ROS packages for Raspbian Stretch" -component="main" -distribution="stretch" rpi-ros-kinetic

    # Add deb-packages to index from `/opt/aptly/ros-kinetic-*`
    aptly repo add rpi-ros-kinetic /opt/aptly/ros-kinetic-*

    # Publish updates
    aptly publish repo rpi-ros-kinetic rpi-ros-kinetic
    ```

    Add new packages:

    ```bash
    # Add deb-packages to index from `/opt/aptly/ros-kinetic/`
    aptly repo add rpi-ros-kinetic /opt/aptly/ros-kinetic/

    # Publish updates
    aptly publish update stretch rpi-ros-kinetic
    ```

    Read [the official documentation](https://www.aptly.info/doc/overview/) for learn more about aptly.

## Configure the mirror

1. Enter to the container. How to attach? See [here](#configure-the-repository).
2. Run `/opt/update_mirror.sh`. This script consists 3 preconfigured configuration which you can use or use your own. For use uncomment one (by default for the Raspbian mirror):

    ```bash
    UPSTREAM_URL="http://raspbian.raspberrypi.org/raspbian/"
    REPO=raspbian
    DISTS=( buster )
    COMPONENTS=( main contrib non-free rpi )
    ARCH=armhf
    ```

3. After that you need to setup the public key is associated with this repo to `/opt/aptly/gpg/trustedkeys.gpg` (it is linked w `/root/.gnupg/trustedkeys.gpg`), for this use `/opt/keys_imp.sh`, otherwise you will catch the error:

    ```log
    ERROR: unable to fetch mirror: verification of detached signature    failed: exit status 2
    ```

> If the script fails due to network disconnects etc, just re-run it.

 The initial download of the repository may take quite some time depending on your bandwidth limits, it may be in your best interest to open a screen, tmux or byobu session before proceeding.

> For host a mirror of Ubuntu's main repository, you'll need upwards of 80GB+ (x86_64 only) of free space as of Feb 2016, plan for growth. Raspbian takes 69GB+.

When the script completes, you should have a functional mirror that you can point a client to.

___

* © 2018-2020 Artem Smirnov
* © 2016 Bryan J. Hong
* Licensed under the Apache License, Version 2.0
