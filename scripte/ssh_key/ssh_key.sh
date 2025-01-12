#!/bin/bash
# sookie-dev auf GitHub
# Dateien befinden sich unter https://github.homelab.global
#
# chmod +x /data/scripte/sshy_key.sh
#
# Nutzung:
# ./ssh_key.sh "ssh-rsa AAAAB3..."

# Datei und SSH-Key definieren
AUTHORIZED_KEYS="/root/.ssh/authorized_keys"
SSH_KEY="$1"

# Überprüfen, ob ein Argument (SSH-Key) übergeben wurde
if [ -z "$SSH_KEY" ]; then
    echo "Bitte den SSH-Key als Argument übergeben."
    echo "Beispiel: ./ssh_key.sh 'ssh-rsa AAAAB3...'"
    exit 1
fi

# Sicherstellen, dass die Datei existiert
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    echo "Die Datei $AUTHORIZED_KEYS existiert nicht. Sie wird erstellt."
    mkdir -p /root/.ssh
    touch "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
fi

# Prüfen, ob der SSH-Key bereits in der Datei vorhanden ist
if grep -qF "$SSH_KEY" "$AUTHORIZED_KEYS"; then
    echo "Der SSH-Key $1 ist bereits in der Datei $AUTHORIZED_KEYS vorhanden."
else
    echo "$SSH_KEY" >> "$AUTHORIZED_KEYS"
    echo "Der SSH-Key $1 wurde erfolgreich zur Datei $AUTHORIZED_KEYS hinzugefügt."
fi
