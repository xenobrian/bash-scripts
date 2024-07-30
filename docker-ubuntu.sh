#!/usr/bin/env bash

if (( $EUID != 0 )); then
    echo "Please execute as root.";
    exit;
fi

function dockerInstall {
        for old_package in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
            apt remove $old_package -y
        done

        apt update;
        apt install ca-certificates curl -y

        for i in {1..3}; do
            install -m -d 0755 /etc/apt/keyrings
        done

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc]https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt update;
        apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        service docker start
}

function userAdd {
    local user="$1"
    usermod -aG docker $user
    grep docker /etc/group
}

dockerInstall

while true; do
    read -rp "User to add to the 'docker' group. Or 'none' to not add another user : " username
done

userAdd "username"