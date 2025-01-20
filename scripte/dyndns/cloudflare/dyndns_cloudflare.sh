#!/bin/bash
# Autor: sookie-dev auf GitHub
# Dateien befinden sich unter https://github.homelab.global

# Variablen
API_TOKEN="dein-cloudflare-api-token"       # Dein API-Token
RECORD_NAME="subdomain.deinedomain.de"      # Name der Subdomain
DNS_TYPES=("A" "AAAA")                      # Typen der DNS-Einträge (A für IPv4, AAAA für IPv6)
TTL=60                                      # TTL (Time To Live) in Sekunden
PROXIED=false                               # Ob Cloudflare den Traffic proxied (true/false)

# Öffentliche IPs ermitteln
CURRENT_IPV4=$(curl -s https://ipv4.icanhazip.com | tr -d '\n')
CURRENT_IPV6=$(curl -s https://ipv6.icanhazip.com | tr -d '\n')

if [ -z "$CURRENT_IPV4" ] && [ -z "$CURRENT_IPV6" ]; then
    echo "Fehler: Weder IPv4 noch IPv6 konnten ermittelt werden."
    exit 1
fi

# Domainname aus RECORD_NAME extrahieren
DOMAIN_NAME=$(echo "$RECORD_NAME" | awk -F. '{print $(NF-1)"."$NF}')

# Zone-ID automatisch ermitteln
ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN_NAME" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json")

ZONE_ID=$(echo "$ZONE_RESPONSE" | grep -o '"id":"[^"]*"' | head -n 1 | sed 's/"id":"\([^"]*\)"/\1/')

if [ -z "$ZONE_ID" ]; then
    echo "Fehler: Zone-ID für $DOMAIN_NAME konnte nicht ermittelt werden."
    exit 1
fi

# Funktion zum Erstellen eines neuen DNS-Records
create_record() {
    local type=$1
    local current_ip=$2

    if [ -z "$current_ip" ]; then
        echo "Keine IP-Adresse für Typ $type vorhanden. Überspringe..."
        return
    fi

    CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$type\",\"name\":\"$RECORD_NAME\",\"content\":\"$current_ip\",\"ttl\":$TTL,\"proxied\":$PROXIED}")

    SUCCESS=$(echo "$CREATE_RESPONSE" | grep -o '"success":true')

    if [ "$SUCCESS" == '"success":true' ]; then
        echo "Ein neuer $type-Record für $RECORD_NAME wurde erfolgreich mit $current_ip erstellt."
    else
        echo "Fehler beim Erstellen des $type-Records: $(echo "$CREATE_RESPONSE" | grep -o '"message":"[^"]*"' | sed 's/"message":"\([^"]*\)"/\1/')"
    fi
}

# Funktion zum Aktualisieren eines DNS-Records
update_record() {
    local type=$1
    local current_ip=$2

    if [ -z "$current_ip" ]; then
        echo "Keine IP-Adresse für Typ $type vorhanden. Überspringe..."
        return
    fi

    # Aktuellen DNS-Record abrufen
    RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=$type&name=$RECORD_NAME" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")

    RECORD_ID=$(echo "$RECORD" | grep -o '"id":"[^"]*"' | head -n 1 | sed 's/"id":"\([^"]*\)"/\1/')
    RECORD_IP=$(echo "$RECORD" | grep -o '"content":"[^"]*"' | sed 's/"content":"\([^"]*\)"/\1/')

    if [ -z "$RECORD_ID" ]; then
        echo "Der $type-Record für $RECORD_NAME existiert nicht. Erstelle neuen Eintrag..."
        create_record "$type" "$current_ip"
        return
    fi

    # Prüfen, ob die IP aktualisiert werden muss
    if [ "$current_ip" == "$RECORD_IP" ]; then
        echo "Die IP des $type-Records ist bereits aktuell: $current_ip"
        return
    fi

    # DNS-Record aktualisieren
    UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$type\",\"name\":\"$RECORD_NAME\",\"content\":\"$current_ip\",\"ttl\":$TTL,\"proxied\":$PROXIED}")

    SUCCESS=$(echo "$UPDATE_RESPONSE" | grep -o '"success":true')

    if [ "$SUCCESS" == '"success":true' ]; then
        echo "Der $type-Record $RECORD_NAME wurde erfolgreich auf $current_ip aktualisiert."
    else
        echo "Fehler bei der Aktualisierung des $type-Records: $(echo "$UPDATE_RESPONSE" | grep -o '"message":"[^"]*"' | sed 's/"message":"\([^"]*\)"/\1/')"
    fi
}

# IPv4 und IPv6 separat aktualisieren oder erstellen
for DNS_TYPE in "${DNS_TYPES[@]}"; do
    if [ "$DNS_TYPE" == "A" ]; then
        update_record "A" "$CURRENT_IPV4"
    elif [ "$DNS_TYPE" == "AAAA" ]; then
        update_record "AAAA" "$CURRENT_IPV6"
    fi
done
