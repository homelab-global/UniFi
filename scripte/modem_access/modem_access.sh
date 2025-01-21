#!/bin/bash
# Autor: sookie-dev auf GitHub
# Dateien befinden sich unter https://github.homelab.global

CONFIG_FILE="/data/scripte/modem_access.conf"
DEFAULT_SUBNET_MASK="/24"  # Standard-Subnetzmaske

# Befehle und Variablen definieren
IPT=$(command -v iptables)
IP_CMD=$(command -v ip)

# Überprüfen, ob die Konfigurationsdatei existiert
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Fehler: Konfigurationsdatei $CONFIG_FILE nicht gefunden." >&2
    exit 1
fi

# Fehlerbehandlungsfunktion
handle_error() {
    echo "Fehler: $1" >&2
    exit 1
}

# Hauptlogik basierend auf der Aktion
case "$1" in
  start)
    echo "Starte Konfiguration für alle MACVLAN-Interfaces..."
    while IFS=',' read -r WAN_INTERFACE LOKALE_IP MODEM_IP || [[ -n "$WAN_INTERFACE" ]]; do
        # Kommentare und leere Zeilen überspringen
        [[ "$WAN_INTERFACE" =~ ^#.*$ || -z "$WAN_INTERFACE" ]] && continue
        
        # Lokale IP-Adresse mit Subnetzmaske erweitern
        LOKALE_IP_WITH_MASK="${LOKALE_IP}${DEFAULT_SUBNET_MASK}"
        echo "Konfiguriere ${WAN_INTERFACE}.modem mit lokaler IP ${LOKALE_IP_WITH_MASK} und Modem-IP ${MODEM_IP}..."

        # MACVLAN-Interface erstellen
        $IP_CMD link add name ${WAN_INTERFACE}.modem link ${WAN_INTERFACE} type macvlan || handle_error "Erstellung des MACVLAN-Interfaces fehlgeschlagen: ${WAN_INTERFACE}.modem"
        $IP_CMD addr add ${LOKALE_IP_WITH_MASK} dev ${WAN_INTERFACE}.modem || handle_error "Zuweisung der IP-Adresse fehlgeschlagen: ${WAN_INTERFACE}.modem"
        $IP_CMD link set ${WAN_INTERFACE}.modem up || handle_error "Aktivierung des Interfaces fehlgeschlagen: ${WAN_INTERFACE}.modem"

        # NAT-Regel hinzufügen
        $IPT -t nat -I POSTROUTING 1 -o ${WAN_INTERFACE}.modem -d ${MODEM_IP} -j MASQUERADE || handle_error "Hinzufügen der NAT-Regel fehlgeschlagen: ${WAN_INTERFACE}.modem"
    done < "$CONFIG_FILE"
    echo "Alle Konfigurationen erfolgreich angewendet."
    ;;

  stop)
    echo "Beende Konfiguration für alle MACVLAN-Interfaces..."
    while IFS=',' read -r WAN_INTERFACE LOKALE_IP MODEM_IP || [[ -n "$WAN_INTERFACE" ]]; do
        # Kommentare und leere Zeilen überspringen
        [[ "$WAN_INTERFACE" =~ ^#.*$ || -z "$WAN_INTERFACE" ]] && continue

        # Lokale IP-Adresse mit Subnetzmaske erweitern
        LOKALE_IP_WITH_MASK="${LOKALE_IP}${DEFAULT_SUBNET_MASK}"
        echo "Entferne Konfiguration von ${WAN_INTERFACE}.modem..."

        # MACVLAN-Interface entfernen und NAT-Regel löschen
        $IP_CMD link set ${WAN_INTERFACE}.modem down || handle_error "Deaktivierung des Interfaces fehlgeschlagen: ${WAN_INTERFACE}.modem"
        $IP_CMD addr del ${LOKALE_IP_WITH_MASK} dev ${WAN_INTERFACE}.modem || handle_error "Entfernung der IP-Adresse fehlgeschlagen: ${WAN_INTERFACE}.modem"
        $IP_CMD link delete dev ${WAN_INTERFACE}.modem || handle_error "Löschen des Interfaces fehlgeschlagen: ${WAN_INTERFACE}.modem"
        $IPT -t nat -D POSTROUTING -o ${WAN_INTERFACE}.modem -d ${MODEM_IP} -j MASQUERADE || handle_error "Löschen der NAT-Regel fehlgeschlagen: ${WAN_INTERFACE}.modem"
    done < "$CONFIG_FILE"
    echo "Alle Konfigurationen erfolgreich entfernt."
    ;;

  *)
    echo "Nutzung: $0 {start|stop}" >&2
    exit 1
    ;;
esac

exit 0
