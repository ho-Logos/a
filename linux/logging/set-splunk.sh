#!/bin/bash
# 
# set-splunk.sh
# 
# set desired Splunk settings
#
# David Reid
# Mar. 2025



# Check if script has been run with superuser privileges
if [[ "$(id -u)" != "0" ]]; then
    printf "${error}ERROR: The script must be run with sudo privileges!${reset}\n"
    exit 1
fi



# Add Splunk binary to script path and save to bash PATH
SPLUNK_HOME="/opt/splunk"
if [[ ":$PATH:" != *":$SPLUNK_HOME/bin:"* ]]; then
    export PATH=$PATH:$SPLUNK_HOME/bin
    echo "export PATH=\$PATH:$SPLUNK_HOME/bin" >> ~/.bashrc
fi

# Add an alias for Splunk
if ! grep -q "alias splunk" ~/.bashrc; then
    echo "alias splunk='$SPLUNK_HOME/bin/splunk'" >> ~/.bashrc
fi

# Affect change and test
source ~/.bashrc
splunk version



# Remove all users except admin
USER_FILE="$SPLUNK_HOME/etc/passwd"
LOG_FILE="/var/log/splunk_deleted_users.log"
USERS_TO_DELETE=$(awk -F: '$2 != "admin" {print $2}' "$USER_FILE")

if [ -z "$USERS_TO_DELETE" ]; then
    printf "${info}No users found to delete${reset}\n"
    echo "$(date): No users found to delete" | tee -a "$LOG_FILE"
else
    for user in $USERS_TO_DELETE; do
        splunk remove user "$user" --accept-license --answer-yes
        if [[ $? -eq 0 ]]; then
            printf "${info}Deleted user $user${reset}\n"
            echo "$(date): Deleted user $user" | tee -a "$LOG_FILE"
        else
            printf "${warn}Failed to delete user $user${reset}\n"
            echo "$(date): Failed to delete user $user" | tee -a "$LOG_FILE" >&2
        fi
    done
fi



# Remove technical add-ons (TAs), aka apps
splunk remove app splunk_secure_gateway -f

# Install apps - this will handle .tgz files
splunk install app ./logging/Splunk_TA_nix.tgz
splunk install app ./logging/Splunk_TA_win.tgz
# add Splunk_TA_paloalto_networks/
# add cisco

# Create indexes
splunk add index nix
splunk add index docker
splunk add index win
splunk add index net

# Enable log collection
# 9997 - universal forwarders
#  514 - palo alto syslog
#  HEC - docker logs
splunk enable listen 9997
splunk add udp 514 -sourcetype syslog -index net
splunk http-event-collector enable -uri https://localhost:8089
splunk http-event-collector create docker_token -uri https://localhost:8089 -disabled 0 -index docker

# Deploy apps to forwarders
splunk enable deploy-server
mv $SPLUNK_HOME/etc/apps/Splunk_TA_nix $SPLUNK_HOME/etc/deployment-apps/
mv $SPLUNK_HOME/etc/apps/Splunk_TA_win $SPLUNK_HOME/etc/deployment-apps/

cat <<EOF > $SPLUNK_HOME/etc/system/local/serverclass.conf
[global]
repositoryLocation = $SPLUNK_HOME/etc/deployment-apps/

[serverClass:All_Forwarders]
whitelist.0 = *

[serverClass:Linux_Forwarders]
machineTypes.0 = linux-x86_64
[serverClass:Linux_Forwarders:app:Splunk_TA_nix]

[serverClass:Windows_Forwarders]
machineTypes.0 = windows-x86_64
machineTypes.1 = windows-x86
[serverClass:Windows_Forwarders:app:Splunk_TA_win]
EOF

splunk reload deploy-server
splunk list deploy-clients
