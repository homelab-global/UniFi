#!/bin/bash

# Autor: sookie-dev auf GitHub
# Dateien befinden sich unter https://github.homelab.global
#
# chmod +x /data/scripte/modem.sh
#
# Nutzung:
# ./modem.sh start <WAN_INTERFACE> <LOKALE_IP> <MODEM_IP>
# ./modem.sh stop <WAN_INTERFACE> <LOKALE_IP> <MODEM_IP>
#
# Beschreibung:
# Dieses Skript erstellt oder entfernt eine MACVLAN-Schnittstelle für den Zugriff auf ein Modem über das WAN-Interface.
# Es richtet außerdem eine NAT-Regel mit iptables ein, um die Kommunikation zu ermöglichen.

# Befehle und Variablen definieren
IPT=$(command -v iptables)    # Pfad zu iptables
IP_CMD=$(command -v ip)       # Pfad zu ip

# Überprüfen, ob die notwendigen Befehle verfügbar sind
if [[ -z "$IPT" || -z "$IP_CMD" ]]; then
    echo "Fehler: Benötigte Befehle iptables und ip sind nicht verfügbar. Bitte installieren." >&2
    exit 1
fi

# Überprüfen, ob genügend Argumente übergeben wurden
if [[ $# -ne 4 ]]; then
    echo "Nutzung: $0 {start|stop} <WAN_INTERFACE> <LOKALE_IP> <MODEM_IP>" >&2
    exit 1
fi

# Argumente parsen
AKTION="$1"                   # Aktion (start oder stop)
WAN_INTERFACE="$2"            # Name des WAN-Interfaces
LOKALE_IP="$3/24"             # Lokale IP-Adresse (im CIDR-Format)
MODEM_IP="$4"                 # Modem-IP-Adresse

# Fehlerbehandlungsfunktion
handle_error() {
    echo "Fehler: $1" >&2
    exit 1
}

# Hauptlogik basierend auf der Aktion
case "$AKTION" in
  start)
    echo "Starte Konfiguration für ${WAN_INTERFACE}.modem..."

    # MACVLAN-Interface erstellen
    $IP_CMD link add name ${WAN_INTERFACE}.modem link ${WAN_INTERFACE} type macvlan || handle_error "Erstellung des MACVLAN-Interfaces fehlgeschlagen"
    $IP_CMD addr add ${LOKALE_IP} dev ${WAN_INTERFACE}.modem || handle_error "Zuweisung der IP-Adresse an ${WAN_INTERFACE}.modem fehlgeschlagen"
    $IP_CMD link set ${WAN_INTERFACE}.modem up || handle_error "Aktivierung des Interfaces ${WAN_INTERFACE}.modem fehlgeschlagen"

    # NAT-Regel hinzufügen
    $IPT -t nat -I POSTROUTING 1 -o ${WAN_INTERFACE}.modem -d ${MODEM_IP} -j MASQUERADE || handle_error "Hinzufügen der iptables-NAT-Regel fehlgeschlagen"

    echo "Konfiguration erfolgreich angewendet."
    ;;

  stop)
    echo "Beende Konfiguration für ${WAN_INTERFACE}.modem..."

    # MACVLAN-Interface entfernen und NAT-Regel löschen
    $IP_CMD link set ${WAN_INTERFACE}.modem down || handle_error "Deaktivierung des Interfaces ${WAN_INTERFACE}.modem fehlgeschlagen"
    $IP_CMD addr del ${LOKALE_IP} dev ${WAN_INTERFACE}.modem || handle_error "Entfernung der IP-Adresse von ${WAN_INTERFACE}.modem fehlgeschlagen"
    $IP_CMD link delete dev ${WAN_INTERFACE}.modem || handle_error "Löschen des MACVLAN-Interfaces fehlgeschlagen"
    $IPT -t nat -D POSTROUTING -o ${WAN_INTERFACE}.modem -d ${MODEM_IP} -j MASQUERADE || handle_error "Löschen der iptables-NAT-Regel fehlgeschlagen"

    echo "Konfiguration erfolgreich entfernt."
    ;;

  *)
    echo "Nutzung: $0 {start|stop} <WAN_INTERFACE> <LOKALE_IP> <MODEM_IP>" >&2
    exit 1
    ;;
esac

exit 0
