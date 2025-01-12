#!/bin/bash
# Autor: sookie-dev auf GitHub
# Dateien befinden sich unter https://github.homelab.global
#
# chmod +x /data/scripte/dyndns_cloudflare.sh
#
# Cloudflare API-Token (unter https://dash.cloudflare.com/profile/api-tokens erstellen)
api_token=""
# Subdomain, die aktualisiert werden soll (z. B. "example.subdomain.com")
subdomain=""
# Zeit zwischen Updates in Sekunden
update_interval=300
# IPv4-Aktualisierung aktivieren (ja/nein)
update_ipv4="ja"
# IPv6-Aktualisierung aktivieren (ja/nein)
update_ipv6="ja"
# URL für IPv4-Abfrage
ipv4_check_url="ifconfig.co"
# URL für IPv6-Abfrage
ipv6_check_url="ifconfig.co"
# ========================================================================

# Funktion: Prüft, ob die Eingabe ja/nein korrekt ist
validate_yes_no() {
    local value="$1"
    if [[ "$value" != "ja" && "$value" != "nein" ]]; then
        echo "Fehler: Ungültiger Wert für $2. Erlaubt sind nur 'ja' oder 'nein'."
        exit 1
    fi
}

# Eingaben validieren
validate_yes_no "$update_ipv4" "update_ipv4"
validate_yes_no "$update_ipv6" "update_ipv6"

# Funktion: Hole Zone-ID von Cloudflare
get_zone_id() {
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$(echo "$subdomain" | awk -F\. '{print $(NF-1) FS $NF}')" \
        -H "Authorization: Bearer $api_token" \
        -H "Content-Type: application/json" | jq -r '.result[0].id'
}

# Funktion: Aktualisiere DNS-Eintrag (A oder AAAA)
update_dns_record() {
    local record_type=$1
    local ip=$2
    local record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$record_type&name=$subdomain" \
        -H "Authorization: Bearer $api_token" \
        -H "Content-Type: application/json")

    if [[ $record == *"\"count\":0"* ]]; then
        echo "Fehler: $subdomain existiert nicht auf Cloudflare."
        return 1
    fi

    local current_ip=$(echo "$record" | jq -r '.result[0].content')
    local record_id=$(echo "$record" | jq -r '.result[0].id')

    if [[ "$ip" == "$current_ip" ]]; then
        echo "Keine Änderung erforderlich. Die IP-Adresse ($ip) ist unverändert und erfordert kein Update."
    else
        local update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
            -H "Authorization: Bearer $api_token" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"$record_type\",\"name\":\"$subdomain\",\"content\":\"$ip\"}")

        if [[ $update == *"\"success\":true"* ]]; then
            echo "Erfolgreich aktualisiert: $record_type $subdomain von $current_ip auf $ip."
        else
            echo "Fehler bei der Aktualisierung von $record_type $subdomain."
        fi
    fi
}

# Überprüfen, ob API-Token und Subdomain gesetzt sind
[ -z "$api_token" ] && { echo "Fehler: API-Token ist nicht gesetzt!"; exit 1; }
[ -z "$subdomain" ] && { echo "Fehler: Subdomain ist nicht gesetzt!"; exit 1; }

# Hauptlogik basierend auf Argumenten
case "$1" in
update)
    echo "Starte Cloudflare DDNS-Update für $subdomain..."
    zone_id="" # Zone-ID wird nur abgefragt, wenn nötig

    while true; do
        # IPv4-Update
        if [[ $update_ipv4 == "ja" ]]; then
            ipv4=$(curl -s -4 https://"$ipv4_check_url")
            if [[ $ipv4 =~ ^(([0-9]{1,3}\.){3}[0-9]{1,3})$ ]]; then
                # DNS-Eintrag prüfen und aktualisieren
                if [[ -z "$zone_id" ]]; then
                    echo "Abrufen der Zone-ID..."
                    zone_id=$(get_zone_id)
                fi
                update_dns_record "A" "$ipv4"
            else
                echo "Fehler: Keine gültige IPv4-Adresse gefunden."
            fi
        fi

        # IPv6-Update
        if [[ $update_ipv6 == "ja" ]]; then
            ipv6=$(curl -s -6 https://"$ipv6_check_url")
            if [[ $ipv6 =~ ^([0-9a-fA-F:]+)$ ]]; then
                # DNS-Eintrag prüfen und aktualisieren
                if [[ -z "$zone_id" ]]; then
                    echo "Abrufen der Zone-ID..."
                    zone_id=$(get_zone_id)
                fi
                update_dns_record "AAAA" "$ipv6"
            else
                echo "Fehler: Keine gültige IPv6-Adresse gefunden."
            fi
        fi

        sleep $update_interval
    done
    ;;

stop)
    echo "Beende Cloudflare DDNS-Updater..."
    pkill -f "$(basename "$0")"
    ;;

*)
    echo "Nutzung: $0 {update|stop}"
    exit 1
    ;;
esac
