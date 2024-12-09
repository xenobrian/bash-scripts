#!/bin/bash
echo "Currently only supports"

if (( $EUID != 0 )); then
    echo "Please execute as root.";
    exit;
fi

function AptDockerInstall {
    local linux_distro="$1"

    for old_package in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
        apt remove $old_package -y
    done

    apt update;
    apt install ca-certificates curl -y

    for i in {1..2}; do
        install -m 0755 -d /etc/apt/keyrings
    done

    curl -fsSL https://download.docker.com/linux/$linux_distro/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$linux_distro \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update;
    apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

    service docker start
}

function RpmDockerInstall {
    local linux_distro="$1"
    case "$linux_distro" in
        "rhel" | "fedora" | "centos")
        packagemanager=dnf;;

        "sles")
        packagemanager=zypper;;
    esac

    if [[ $linux_distro = "sles" ]]; then
        opensuse_repo="https://download.opensuse.org/repositories/security:/SELinux/openSUSE_Factory/security:SELinux.repo"
        zypper addrepo $opensuse_repo
        zypper addrepo https://download.docker.com/linux/sles/docker-ce.repo
    else
        dnf -y install dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/$linux_distro/docker-ce.repo
    fi

    $packagemanager remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine -y

    if [[ $linux_distro = "fedora" ]]; then
        dnf remove docker-selinux docker-engine-selinux -y
    elif [[$linux_distro = "sles" ]]; then
        zypper remove runc;
    fi

    $packagemanager install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable --now docker
}

case "$(lsb_release -is)" in
    "Debian")
        echo "You are running Debian"
        AptDockerInstall "debian";;

    "Ubuntu")
        echo "You are running Ubuntu"
        AptDockerInstall "ubuntu";;

    "Fedora")
        echo "You are running a Fedora."
        RpmDockerInstall "fedora";;

    "openSUSE" | "SUSE")
        echo "You are running openSUSE, or SLES."
        RpmDockerInstall "sles";;

    "RedhatEnterpriseServer")
        echo "You are running RHEL."
        RpmDockerInstall "rhel";;

    "CentOS")
        echo "You are running CentOS"
        RpmDockerInstall "centos";;

    "AlmaLinux" | "Rocky" )
        echo "You are running a RHEL or its derivative."
        RpmDockerInstall "rhel";;
esac

function userAdd {
    local user="$1"
    usermod -aG docker $user
    grep docker /etc/group
}

read -rp "User to add to the 'docker' group. Or 'none' to not add another user : " username
userAdd "$username"