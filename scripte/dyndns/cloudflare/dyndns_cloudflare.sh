#!/bin/bash
# Autor: sookie-dev auf GitHub
# Dateien befinden sich unter https://github.homelab.global

# Konfigurationsdatei definieren
CONFIG_FILE="$(dirname "$(realpath "$0")")/dyndns_cloudflare.conf"

# Prüfen, ob die Konfigurationsdatei existiert
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Konfigurationsdatei nicht gefunden: $CONFIG_FILE"
    exit 1
fi

# Öffentliche IPs ermitteln
CURRENT_IPV4=$(curl -s https://ipv4.icanhazip.com | tr -d '\n')
CURRENT_IPV6=$(curl -s https://ipv6.icanhazip.com | tr -d '\n')

if [ -z "$CURRENT_IPV4" ] && [ -z "$CURRENT_IPV6" ]; then
    echo "Fehler: Weder IPv4 noch IPv6 konnten ermittelt werden."
    exit 1
fi

# Funktion zur Ermittlung der Zone-ID für eine Domain
get_zone_id() {
    local domain=$1
    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")

    echo "$response" | grep -o '"id":"[^"]*"' | head -n 1 | sed 's/"id":"\([^"]*\)"/\1/'
}

# Funktion zur Extraktion der Hauptdomain aus einer Subdomain
extract_domain() {
    local subdomain=$1
    echo "$subdomain" | awk -F'.' '{print $(NF-1)"."$NF}'
}

# Funktion zum Erstellen eines neuen DNS-Records
create_record() {
    local type=$1
    local record_name=$2
    local current_ip=$3
    local zone_id=$4
    local proxied=$5

    if [ -z "$current_ip" ]; then
        echo "Keine IP-Adresse für Typ $type vorhanden. Überspringe..."
        return
    fi

    local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$type\",\"name\":\"$record_name\",\"content\":\"$current_ip\",\"ttl\":$TTL,\"proxied\":$proxied}")

    local success=$(echo "$response" | grep -o '"success":true')

    if [ "$success" == '"success":true' ]; then
        echo "Neuer $type-Record für $record_name erfolgreich mit $current_ip erstellt."
    else
        echo "Fehler beim Erstellen des $type-Records für $record_name: $(echo "$response" | grep -o '"message":"[^"]*"' | sed 's/"message":"\([^"]*\)"/\1/')"
    fi
}

# Funktion zum Aktualisieren eines bestehenden DNS-Records
update_record() {
    local type=$1
    local record_name=$2
    local current_ip=$3
    local zone_id=$4
    local proxied=$5

    if [ -z "$current_ip" ]; then
        echo "Keine IP-Adresse für Typ $type vorhanden. Überspringe..."
        return
    fi

    # Bestehenden DNS-Record abrufen
    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$type&name=$record_name" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")

    local record_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -n 1 | sed 's/"id":"\([^"]*\)"/\1/')
    local record_ip=$(echo "$response" | grep -o '"content":"[^"]*"' | sed 's/"content":"\([^"]*\)"/\1/')

    if [ -z "$record_id" ]; then
        echo "Der $type-Record für $record_name existiert nicht. Erstelle neuen Eintrag..."
        create_record "$type" "$record_name" "$current_ip" "$zone_id" "$proxied"
        return
    fi

    # Prüfen, ob die IP aktualisiert werden muss
    if [ "$current_ip" == "$record_ip" ]; then
        echo "Die IP des $type-Records für $record_name ist bereits aktuell: $current_ip"
        return
    fi

    # DNS-Record aktualisieren
    local update_response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$type\",\"name\":\"$record_name\",\"content\":\"$current_ip\",\"ttl\":$TTL,\"proxied\":$proxied}")

    local success=$(echo "$update_response" | grep -o '"success":true')

    if [ "$success" == '"success":true' ]; then
        echo "Der $type-Record für $record_name wurde erfolgreich auf $current_ip aktualisiert."
    else
        echo "Fehler bei der Aktualisierung des $type-Records für $record_name: $(echo "$update_response" | grep -o '"message":"[^"]*"' | sed 's/"message":"\([^"]*\)"/\1/')"
    fi
}

# Verarbeitung aller Subdomains aus der Konfiguration
for record in "${DNS_RECORDS[@]}"; do
    read -r record_name dns_types proxied <<< "$record"

    # Automatische Extraktion der Domain aus der Subdomain
    domain=$(extract_domain "$record_name")

    echo "Bearbeite $record_name ($domain)..."

    # Zone-ID für die Domain ermitteln
    zone_id=$(get_zone_id "$domain")

    if [ -z "$zone_id" ]; then
        echo "Fehler: Zone-ID für $domain konnte nicht ermittelt werden."
        continue
    fi

    # DNS-Typen (A oder AAAA oder beide) verarbeiten
    IFS=',' read -ra types <<< "$dns_types"
    for type in "${types[@]}"; do
        if [[ "$type" == "A" ]]; then
            update_record "A" "$record_name" "$CURRENT_IPV4" "$zone_id" "$proxied"
        elif [[ "$type" == "AAAA" ]]; then
            update_record "AAAA" "$record_name" "$CURRENT_IPV6" "$zone_id" "$proxied"
        fi
    done
done
