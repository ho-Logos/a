#!/bin/sh
# generated by claude.ai then modified
# 
# Give it a list of valid usernames and it will try to find ones not in the list

# Create a temporary file to store allowed usernames
ALLOWED_USERS_FILE=$(mktemp)

# Add protected users that should never be locked
echo "root" >> "$ALLOWED_USERS_FILE"
echo "sysadmin" >> "$ALLOWED_USERS_FILE"

# If a username file was provided, add those users to the allowed list
if [ $# -eq 1 ]; then
    FILE="$1"
    
    # Check if the file exists
    if [ -f "$FILE" ]; then
        # Extract usernames from file (assuming one username per line)
        cat "$FILE" | tr -d '\r' >> "$ALLOWED_USERS_FILE"
        echo "Added users from $FILE to allowed list."
    else
        echo "Warning: File $FILE not found. Only protecting system accounts, root, and sysadmin."
    fi
else
    echo "No file provided. Only protecting system accounts, root, and sysadmin."
fi

# Define known login shells
is_login_shell() {
    case "$1" in
        */bash|*/sh|*/zsh|*/ksh|*/dash|*/tcsh|*/csh|*/fish)
            return 0 ;;  # It's a login shell
        *)
            return 1 ;;  # Not a login shell
    esac
}

# Process each user in /etc/passwd
echo "Checking user accounts..."
while IFS=: read -r username _ uid gid _ home shell; do
    
    # Check if the shell is a login shell
    if is_login_shell "$shell"; then
        # Only process accounts with login shells
        if ! grep -q "^${username}$" "$ALLOWED_USERS_FILE"; then
            echo "Found account: $username (shell: $shell)"
            #passwd -l "$username"
        else
            printf ""
            #echo "Preserving allowed account: $username"
        fi
    else
        printf ""
        #echo "Skipping service account: $username (shell: $shell)"
    fi
done < /etc/passwd

# Clean up
rm -f "$ALLOWED_USERS_FILE"

echo "Account locking complete."
