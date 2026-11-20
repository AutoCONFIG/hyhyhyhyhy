#!/usr/bin/env bash
set -euo pipefail

sudo -E apt-mark hold grub-efi-amd64-signed
sudo -E apt update
sudo -E apt-get -y purge azure-cli* docker* ghc* llvm* firefox* google* dotnet* aspnetcore* powershell* mysql* php* mongodb* snap*
sudo -E apt-get -y install coreutils build-essential cmake ninja-build git libncurses-dev libpython3-dev python3-setuptools python3-pyelftools swig
sudo -E systemctl daemon-reload
sudo -E apt -y autoremove --purge
sudo -E apt clean
install --version | grep 'GNU coreutils'
sudo -E rm -rf /usr/share/dotnet /etc/mysql /etc/php /usr/local/lib/android /opt/ghc /opt/hostedtoolcache/CodeQL /usr/local/.ghcup /usr/share/swift /usr/local/share/powershell /usr/local/lib/heroku
sudo -E timedatectl set-timezone "Asia/Shanghai"
