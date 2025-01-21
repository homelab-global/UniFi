#!/bin/bash
# Autor: sookie-dev auf GitHub
# Dateien befinden sich unter https://github.homelab.global
#
# Nutzung:
# ./ssh_key.sh "ssh-rsa AAAAB3..." "ssh-rsa BBBB44..." "ssh-ed25519 CCCC55..."

# Datei definieren
AUTHORIZED_KEYS="/root/.ssh/authorized_keys"

# Überprüfen, ob mindestens ein Argument (SSH-Key) übergeben wurde
if [ "$#" -lt 1 ]; then
    echo "Bitte mindestens einen SSH-Key als Argument übergeben."
    echo "Beispiel: ./ssh_key.sh 'ssh-rsa AAAAB3...' 'ssh-ed25519 BBBB44...'"
    exit 1
fi

# Sicherstellen, dass die Datei existiert
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    echo "Die Datei $AUTHORIZED_KEYS existiert nicht. Sie wird erstellt."
    mkdir -p /root/.ssh
    touch "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
fi

# Jeden übergebenen SSH-Key prüfen und hinzufügen
for SSH_KEY in "$@"; do
    # Prüfen, ob der SSH-Key bereits in der Datei vorhanden ist
    if grep -qF "$SSH_KEY" "$AUTHORIZED_KEYS"; then
        echo "Der SSH-Key \"$SSH_KEY\" ist bereits in der Datei $AUTHORIZED_KEYS vorhanden."
    else
        echo "$SSH_KEY" >> "$AUTHORIZED_KEYS"
        echo "Der SSH-Key \"$SSH_KEY\" wurde erfolgreich zur Datei $AUTHORIZED_KEYS hinzugefügt."
    fi
done
