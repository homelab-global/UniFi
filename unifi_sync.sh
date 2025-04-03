#!/bin/bash

# --------------------
# Konfiguration
# --------------------
API_URL="..."
API_TOKEN="..."

controller_ip="https://127.0.0.1:443"
controller_user="..."
controller_pass="..."
SITE="default"

tmp_dir="/tmp/unifi_sync"
mkdir -p "$tmp_dir"
COOKIE_FILE="$tmp_dir/unifi_cookie.txt"

# Hilfsfunktion für Fehlermeldungen und Beenden
die() {
  echo "[!] FEHLER: $1"
  exit 1
}

# --------------------
# Schritt 1: Login beim UniFi Controller
# --------------------
echo "🔐 Melde mich beim UniFi Controller an..."

csrf_token=$(curl -sk -X POST "$controller_ip/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$controller_user\",\"password\":\"$controller_pass\"}" \
  -c "$COOKIE_FILE" -D - -o /dev/null \
  | tr -d '\r' | grep -i '^x-csrf-token:' | head -n1 | awk -F': ' '{print $2}')

if [[ -z "$csrf_token" ]]; then
  die "Login fehlgeschlagen! Kann nicht ohne Authentifizierung fortfahren."
fi

echo "[+] Login erfolgreich."

# --------------------
# Schritt 2: Lokalen Gateway-Namen ermitteln
# --------------------
echo "[*] Ermittle lokalen Gateway-Namen..."

gateway_json=$(curl -sk -X GET "$controller_ip/proxy/network/api/s/$SITE/stat/device" \
  -H "x-csrf-token: $csrf_token" -b "$COOKIE_FILE")

if [[ -z "$gateway_json" ]]; then
  die "Keine Antwort vom Controller bei Gateway-Abfrage!"
fi

echo "$gateway_json" | jq . > /dev/null 2>&1 || die "Ungültiges JSON bei Gateway-Abfrage!"

local_gateway=$(echo "$gateway_json" | jq -r '.data[] | select(.name | test("^gate\\.")) | .name' | head -n1)

if [[ -z "$local_gateway" ]]; then
  die "Kein Gateway gefunden!"
fi

echo "[+] Lokaler Gateway: $local_gateway"

# --------------------
# Schritt 3: Zeitstempel prüfen
# --------------------
echo "[⏳] Prüfe letzten Änderungszeitpunkt für Gateway..."

LAST_SYNC_FILE=".last_sync_$local_gateway"

api_response=$(curl -s -H "X-API-Token: $API_TOKEN" "$API_URL/gateway-status/$local_gateway")
if [[ -z "$api_response" ]]; then
  die "Fehler beim Abrufen des Gateway-Status. API nicht erreichbar!"
fi

echo "$api_response" | jq . > /dev/null 2>&1 || die "Ungültiges JSON bei Gateway-Status-Abfrage!"

API_TIMESTAMP=$(echo "$api_response" | jq -r '.letztesUpdate')

if [ -z "$API_TIMESTAMP" ]; then
  die "Fehler beim Abrufen des Zeitstempels."
fi

if [ -f "$LAST_SYNC_FILE" ]; then
  LOCAL_TIMESTAMP=$(cat "$LAST_SYNC_FILE")
  if [ "$API_TIMESTAMP" == "$LOCAL_TIMESTAMP" ]; then
    echo "[✅] Keine Änderungen erkannt seit letztem Sync ($API_TIMESTAMP)."
    exit 0
  fi
fi

echo "[🔄] Änderungen erkannt, beginne mit Synchronisation..."

# --------------------
# Schritt 4: Benutzerliste abrufen
# --------------------
user_response=$(curl -s -H "X-API-Token: $API_TOKEN" "$API_URL/gateway-users/$local_gateway")

if [ -z "$user_response" ]; then
  die "Fehler beim Abrufen der Benutzerliste. API nicht erreichbar!"
fi

echo "$user_response" | jq . > /dev/null 2>&1 || die "Ungültiges JSON von API beim Abrufen der Benutzerliste"

USERS_JSON="$user_response"

# Sicherstellen, dass es sich um ein Array handelt
user_count=$(echo "$USERS_JSON" | jq '. | length')
if ! [[ "$user_count" =~ ^[0-9]+$ ]]; then
  die "Ungültiges Format der Benutzerliste - kein Array erhalten!"
fi

# --------------------
# Schritt 5: Benutzer erstellen / updaten
# --------------------
declare -A valid_users

while read -r user; do
  username=$(echo "$user" | jq -r '.benutzer')
  password=$(echo "$user" | jq -r '.passwort')
  tunnel_type=$(echo "$user" | jq -r '.tunnel_typ')
  tunnel_medium=$(echo "$user" | jq -r '.tunnel_medium_typ')
  vlan_id=$(echo "$user" | jq -r '.vlan_id')

  # Überprüfen der erforderlichen Felder
  if [[ -z "$username" || "$username" == "null" ]]; then
    echo "[!] WARNUNG: Benutzer ohne Namen übersprungen"
    continue
  fi
  
  if [[ -z "$password" || "$password" == "null" ]]; then
    echo "[!] WARNUNG: Benutzer $username hat kein Passwort, wird übersprungen"
    continue
  fi

  valid_users["$username"]=1

  user_data=$(curl -sk -H "x-csrf-token: $csrf_token" -b "$COOKIE_FILE" \
    "$controller_ip/proxy/network/api/s/$SITE/rest/account")
  
  # Prüfen, ob API-Aufruf erfolgreich war
  if [[ -z "$user_data" ]]; then
    die "Fehler beim Abrufen der Benutzerdaten vom Controller. API nicht erreichbar!"
  fi
  
  echo "$user_data" | jq . > /dev/null 2>&1 || die "Ungültiges JSON bei Benutzerdaten-Abfrage!"

  user_data_filtered=$(echo "$user_data" | jq -c --arg name "$username" '.data[]? | select(.name == $name)')
  user_id=$(echo "$user_data_filtered" | jq -r '._id')

  payload=$(jq -n \
    --arg name "$username" \
    --arg x_password "$password" \
    --arg vlan "$vlan_id" \
    --argjson tunnel_type "$tunnel_type" \
    --argjson tunnel_medium_type "$tunnel_medium" \
    '{name: $name, x_password: $x_password, tunnel_type: $tunnel_type, tunnel_medium_type: $tunnel_medium_type, vlan: $vlan}')

  if [[ -n "$user_id" && "$user_id" != "null" ]]; then
    # Check, ob Änderungen notwendig sind
    current_payload=$(echo "$user_data_filtered" | jq '{name, x_password, tunnel_type, tunnel_medium_type, vlan}')
    if [[ "$current_payload" == "$payload" ]]; then
      echo "[↩️] Keine Änderung bei $username, wird übersprungen."
      continue
    fi
    echo "[✏️] Aktualisiere $username..."
    response=$(curl -sk -X PUT \
      -H "Content-Type: application/json" \
      -H "x-csrf-token: $csrf_token" \
      -b "$COOKIE_FILE" \
      -d "$payload" \
      "$controller_ip/proxy/network/api/s/$SITE/rest/account/$user_id")
    
    if [[ -z "$response" ]]; then
      die "Fehler beim Aktualisieren von $username. Keine Antwort vom Server!"
    fi

    status=$(echo "$response" | jq -r '.meta.rc' 2>/dev/null)
    if [[ "$status" == "ok" ]]; then
      echo "[✅] $username aktualisiert"
    else
      echo "[❌] Fehler beim Aktualisieren von $username: $response"
    fi
  else
    echo "[➕] Erstelle $username..."
    response=$(curl -sk -X POST \
      -H "Content-Type: application/json" \
      -H "x-csrf-token: $csrf_token" \
      -b "$COOKIE_FILE" \
      -d "$payload" \
      "$controller_ip/proxy/network/api/s/$SITE/rest/account")
    
    if [[ -z "$response" ]]; then
      die "Fehler beim Erstellen von $username. Keine Antwort vom Server!"
    fi

    status=$(echo "$response" | jq -r '.meta.rc' 2>/dev/null)
    if [[ "$status" == "ok" ]]; then
      echo "[✅] $username hinzugefügt"
    else
      echo "[❌] Fehler beim Hinzufügen von $username: $response"
    fi
  fi

done < <(echo "$USERS_JSON" | jq -c '.[]?')

# --------------------
# Schritt 6: Veraltete Benutzer löschen
# --------------------
echo "[*] Suche veraltete Benutzer zur Löschung..."

# Alle aktuellen Benutzer vom UniFi Controller abrufen
declare -A user_ids
controller_response=$(curl -sk -H "x-csrf-token: $csrf_token" -b "$COOKIE_FILE" \
  "$controller_ip/proxy/network/api/s/$SITE/rest/account")

if [[ -z "$controller_response" ]]; then
  die "Fehler beim Abrufen der bestehenden Benutzer. Kann nicht ohne diese Daten fortfahren!"
fi

echo "$controller_response" | jq . > /dev/null 2>&1 || die "Ungültiges JSON bei Abruf der bestehenden Benutzer!"

# Überprüfen, ob 'data' und sein Inhalt vorhanden ist
data_check=$(echo "$controller_response" | jq -r 'has("data")')
if [[ "$data_check" != "true" ]]; then
  die "Keine 'data' in der Antwort des Controllers gefunden!"
fi

data_length=$(echo "$controller_response" | jq '.data | length')
if [[ "$data_length" -eq 0 ]]; then
  echo "[!] Warnung: Controller hat keine Benutzer zurückgegeben!"
fi

controller_users="$controller_response"

while read -r name id; do
  if [[ -n "$name" && -n "$id" && "$name" != "null" && "$id" != "null" ]]; then
    user_ids["$name"]="$id"
  fi
done < <(echo "$controller_users" | jq -r '.data[] | "\(.name) \(._id)"')

# Jetzt veraltete User löschen
users_deleted=false
for existing_username in "${!user_ids[@]}"; do
  if [[ -z "${valid_users[$existing_username]:-}" ]]; then
    echo "[🗑️] Lösche $existing_username..."
    delete_response=$(curl -sk -X DELETE "$controller_ip/proxy/network/api/s/$SITE/rest/account/${user_ids[$existing_username]}" \
      -H "x-csrf-token: $csrf_token" \
      -b "$COOKIE_FILE")

    if [[ -z "$delete_response" ]]; then
      die "Fehler beim Löschen von $existing_username. Keine Antwort vom Server!"
    fi

    if echo "$delete_response" | grep -q '"rc":"ok"'; then
      echo "[✅] $existing_username gelöscht."
      users_deleted=true
    else
      echo "[❌] Fehler beim Löschen von $existing_username: $delete_response"
    fi
  fi
done

if [ "$users_deleted" = false ]; then
  echo "[=] Keine veralteten Benutzer gefunden, nichts gelöscht."
fi

# Zeitstempel speichern
echo "$API_TIMESTAMP" > "$LAST_SYNC_FILE"
echo "[+] Synchronisation abgeschlossen."
