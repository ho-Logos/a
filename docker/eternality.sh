#!/bin/bash
# 
# eternality.sh
#
# Eternality - The quality or state of being eternal/everlasting 
#
# Automates setting up the docker environment as much as possible
# 
# Kaicheng Ye
# Dec. 2024

if [[ "$(id -u)" != "0" ]]
then
    printf "${error}ERROR: The script must be run with sudo privileges!${reset}\n"
    exit 1
fi

printf "${info}Starting Docker setup script${reset}\n"

printf "\nWARNING: DO NOT RUN this in a tmux session\n"
printf "Run this detatched in a normal terminal\n"
printf "Continue? [y/n]: "
read input

if [[ "$input" == "N" ]] || [[ "$input" == "n" ]]
then
    exit 0
fi

# install docker
apt-get install docker docker-compose docker-compose-v2 -y

# start ssh for file transfer and remote administration
systemctl enable ssh
systemctl start ssh

# allow 22 tcp through iptables
printf "22\nt" > ./ports.txt
cat ./ports.txt | ../linux-scripts/firewall.sh
rm -rf ./ports.txt

# allow docker service ports
printf "25\nt\n53\nt\n80\nt\n110\nt\n5353\nt\n8000\nt\n8088\nt\n53\nu\n5353\nu" > ./ports.txt
cat ./ports.txt | ./docker-iptables.sh
rm -rf ./ports.txt

# update docker daemon with custom configs
cp ./daemon.json /etc/docker/daemon.json
systemctl restart docker

# start tmux dashboards
./watchfulwhale.sh
./worryingwhale.sh

printf "${info}Finished Docker setup script${reset}\n"

exit 0
