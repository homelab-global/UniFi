#!/bin/bash
# Autor: sookie-dev auf GitHub
# Dateien befinden sich unter https://github.homelab.global

CONFIG_FILE="/data/scripte/modem_access.conf"
MODEMS_FILE="/data/scripte/modem_access.db"
DEFAULT_SUBNET_MASK="/24"  # Standard-Subnetzmaske

# Befehle und Variablen definieren
IPT=$(command -v iptables)
IP_CMD=$(command -v ip)

# Überprüfen, ob die notwendigen Befehle verfügbar sind
if [[ -z "$IPT" || -z "$IP_CMD" ]]; then
    echo "Fehler: Benötigte Befehle iptables und ip sind nicht verfügbar. Bitte installieren." >&2
    exit 1
fi

# Funktion zur Überprüfung auf MACVLAN-Unterstützung
check_macvlan_support() {
    if ! grep -qw "macvlan" /proc/modules; then
        echo "Fehler: Der Kernel unterstützt MACVLAN nicht oder das Modul 'macvlan' ist nicht verfügbar." >&2
        exit 1
    fi
}

# Überprüfen, ob die Konfigurationsdateien existieren
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Fehler: Konfigurationsdatei $CONFIG_FILE nicht gefunden." >&2
    exit 1
fi

if [[ ! -f "$MODEMS_FILE" ]]; then
    echo "Fehler: Datei mit Modemkonfigurationen $MODEMS_FILE nicht gefunden." >&2
    exit 1
fi

# Vordefinierte Modems aus Datei lesen
declare -A PREDEFINED_MODEMS
while IFS=',' read -r MODEM_NAME MODEM_IP LOCAL_IP || [[ -n "$MODEM_NAME" ]]; do
    [[ "$MODEM_NAME" =~ ^#.*$ || -z "$MODEM_NAME" ]] && continue  # Kommentare und leere Zeilen ignorieren
    PREDEFINED_MODEMS["$MODEM_NAME"]="$MODEM_IP,$LOCAL_IP"
done < "$MODEMS_FILE"

# Fehlerbehandlungsfunktion
handle_error() {
    echo "Fehler: $1" >&2
    exit 1
}

# Funktion zur Verarbeitung von Modemkonfigurationen
process_modem() {
    local wan_interface="$1"
    local modem_ip="$2"
    local local_ip="$3"

    LOKALE_IP_WITH_MASK="${local_ip}${DEFAULT_SUBNET_MASK}"
    echo "Konfiguriere $wan_interface.modem mit Modem-IP=$modem_ip, Lokale-IP=$local_ip"

    $IP_CMD link add name ${wan_interface}.modem link ${wan_interface} type macvlan || handle_error "Fehler beim Erstellen von ${wan_interface}.modem"
    $IP_CMD addr add ${LOKALE_IP_WITH_MASK} dev ${wan_interface}.modem || handle_error "Fehler beim Hinzufügen der IP ${local_ip} zu ${wan_interface}.modem"
    $IP_CMD link set ${wan_interface}.modem up || handle_error "Fehler beim Aktivieren von ${wan_interface}.modem"

    $IPT -t nat -I POSTROUTING 1 -o ${wan_interface}.modem -d ${modem_ip} -j MASQUERADE || handle_error "Fehler beim Hinzufügen der NAT-Regel"
}

# Hauptlogik basierend auf der Aktion
case "$1" in
  start)
    # Überprüfen, ob MACVLAN unterstützt wird
    check_macvlan_support

    echo "Starte Konfiguration für alle MACVLAN-Interfaces..."
    while IFS=',' read -r WAN_INTERFACE FIRST_ARG SECOND_ARG || [[ -n "$WAN_INTERFACE" ]]; do
        # Kommentare und leere Zeilen überspringen
        [[ "$WAN_INTERFACE" =~ ^#.*$ || -z "$WAN_INTERFACE" ]] && continue

        if [[ -n "${PREDEFINED_MODEMS[$FIRST_ARG]}" ]]; then
            # Verarbeite vordefiniertes Modem
            IFS=',' read -r modem_ip local_ip <<<"${PREDEFINED_MODEMS[$FIRST_ARG]}"
            process_modem "$WAN_INTERFACE" "$modem_ip" "$local_ip"
        else
            # Verarbeite manuelle Konfiguration
            process_modem "$WAN_INTERFACE" "$FIRST_ARG" "$SECOND_ARG"
        fi
    done < "$CONFIG_FILE"
    echo "Alle Konfigurationen erfolgreich angewendet."
    ;;

  stop)
    echo "Beende Konfiguration für alle MACVLAN-Interfaces..."
    while IFS=',' read -r WAN_INTERFACE FIRST_ARG SECOND_ARG || [[ -n "$WAN_INTERFACE" ]]; do
        # Kommentare und leere Zeilen überspringen
        [[ "$WAN_INTERFACE" =~ ^#.*$ || -z "$WAN_INTERFACE" ]] && continue

        if [[ -n "${PREDEFINED_MODEMS[$FIRST_ARG]}" ]]; then
            # Verarbeite vordefiniertes Modem
            IFS=',' read -r modem_ip local_ip <<<"${PREDEFINED_MODEMS[$FIRST_ARG]}"
            LOKALE_IP_WITH_MASK="${local_ip}${DEFAULT_SUBNET_MASK}"
        else
            # Verarbeite manuelle Konfiguration
            modem_ip="$FIRST_ARG"
            local_ip="$SECOND_ARG"
            LOKALE_IP_WITH_MASK="${local_ip}${DEFAULT_SUBNET_MASK}"
        fi

        echo "Entferne Konfiguration von ${WAN_INTERFACE}.modem..."
        $IP_CMD link set ${WAN_INTERFACE}.modem down || handle_error "Fehler beim Deaktivieren von ${WAN_INTERFACE}.modem"
        $IP_CMD addr del ${LOKALE_IP_WITH_MASK} dev ${WAN_INTERFACE}.modem || handle_error "Fehler beim Entfernen der IP-Adresse von ${WAN_INTERFACE}.modem"
        $IP_CMD link delete dev ${WAN_INTERFACE}.modem || handle_error "Fehler beim Löschen von ${WAN_INTERFACE}.modem"
        $IPT -t nat -D POSTROUTING -o ${WAN_INTERFACE}.modem -d ${modem_ip} -j MASQUERADE || handle_error "Fehler beim Entfernen der NAT-Regel"
    done < "$CONFIG_FILE"
    echo "Alle Konfigurationen erfolgreich entfernt."
    ;;

  *)
    echo "Nutzung: $0 {start|stop}" >&2
    exit 1
    ;;
esac

exit 0
