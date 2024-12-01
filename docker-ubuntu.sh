#!/bin/bash

if (( $EUID != 0 )); then
    echo "Please execute as root.";
    exit;
fi

linux_distro = ''

case "$(lsb_release)" in
    "Debian")
        echo "You are running Debian"
        linux_distro = "Debian";;

    "Ubuntu")
        echo "You are running Ubuntu"
        linux_distro = "Ubuntu";;

    "AlmaLinux" | "Rocky" | "RedhatEnterpriseServer" |  "CentOS")
        echo "You are running a RHEL or its derivative."
        linux_distro = "RHEL-like";;

    "Fedora" | "openSUSE")
        echo "You are running a non-RHEL, rpm-using Linux distribution."
        linux_distro = "rpm-using";;
esac

function dockerInstall {
        local packagemanager = ''

        if [[ $linux_distro = "Debian" ]] || [[ $linux_distro = "Ubuntu" ]]; then
            packagemanager='apt'
        elif [[ $linux_distro = "RHEL-like"]]; then
            packagemanager='dnf'
            dockerRHELinstall
        elif [[ linux_distro = "rpm-using"]]; then
            packagemanager='dnf'
            dockerRPMinstall
        fi

        for old_package in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
            apt remove $old_package -y
        done

        apt update;
        apt install ca-certificates curl -y

        for i in {1..2}; do
            install -m 0755 -d /etc/apt/keyrings
        done

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt update;
        apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

        service docker start
}

function userAdd {
    local user="$1"
    usermod -aG docker $user
    grep docker /etc/group
}

dockerInstall


read -rp "User to add to the 'docker' group. Or 'none' to not add another user : " username
userAdd "$username"