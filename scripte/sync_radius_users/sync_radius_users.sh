#!/bin/bash
# ======= Robuste Optionen aktivieren ========
set -euo pipefail
trap 'echo "[✘] Fehler in Zeile $LINENO – Skript abgebrochen."; exit 1' ERR

# ======= Konfiguration ========
CONTROLLER="https://127.0.0.1:443"
USERNAME="..."
PASSWORD="..."
SITE="default"
COOKIE_FILE="cookie.txt"

# ======= GitHub Repo + Token (privat) ========
GITHUB_TOKEN="ghp_..."
RAW_URL="https://api.github.com/repos/.../.../contents/..."
HASH_FILE="/tmp/sync_radius_users.hash"

# ======= Optionen ========
ENABLE_AUTO_DELETE=true

# ======= SHA-Prüfung vor Download ========
echo "[*] Prüfe, ob sich die Benutzerdatei geändert hat..."
latest_sha=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$RAW_URL" | jq -r '.sha')

if [[ -f "$HASH_FILE" ]]; then
  previous_sha=$(cat "$HASH_FILE")
else
  previous_sha=""
fi

if [[ "$latest_sha" == "$previous_sha" ]]; then
  echo "[=] Keine Änderung in users-Datei – Skript wird übersprungen."
  exit 0
fi

echo "$latest_sha" > "$HASH_FILE"
echo "[+] Neue Version erkannt – Skript wird fortgesetzt..."

# ======= GitHub-Datei laden in Variable ========
echo "[*] Lade zentrale Benutzerdatei direkt in Variable..."

user_data=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                 -H "Accept: application/vnd.github.v3.raw" \
                 "$RAW_URL")

if [[ -z "$user_data" ]]; then
  echo "[!] Fehler beim Laden der Datei!"
  exit 1
fi

echo "[+] Benutzerdatei erfolgreich geladen (via Variable)"

# ======= Login beim UniFi Controller ========
echo "[*] Logging in..."

csrf_token=$(curl -sk -X POST "$CONTROLLER/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" \
  -c "$COOKIE_FILE" -D - -o /dev/null \
  | tr -d '\r' | grep -i '^x-csrf-token:' | head -n1 | awk -F': ' '{print $2}')

if [[ -z "$csrf_token" ]]; then
  echo "[!] Login fehlgeschlagen!"
  exit 1
fi

echo "[+] Login erfolgreich."

# ======= Lokalen Gateway-Namen ermitteln ========
echo "[*] Ermittle lokalen Gateway-Namen..."

gateway_json=$(curl -sk -X GET "$CONTROLLER/proxy/network/api/s/$SITE/stat/device" \
  -H "x-csrf-token: $csrf_token" -b "$COOKIE_FILE")

local_gateway=$(echo "$gateway_json" | jq -r '.data[] | select(.name | test("^gate\\.")) | .name' | head -n1)

if [[ -z "$local_gateway" ]]; then
  echo "[!] Kein Gateway gefunden!"
  exit 1
fi

echo "[+] Lokaler Gateway: $local_gateway"

# ======= Bestehende Benutzer in Arrays laden ========
echo "[*] Lade bestehende Benutzer vom Controller..."

user_list=$(curl -sk -b "$COOKIE_FILE" -H "x-csrf-token: $csrf_token" \
  "$CONTROLLER/proxy/network/api/s/$SITE/rest/account")

declare -A user_ids user_vlans user_tts user_tms valid_users

while IFS= read -r line; do
  name=$(echo "$line" | jq -r '.name')
  user_ids["$name"]=$(echo "$line" | jq -r '._id')
  user_vlans["$name"]=$(echo "$line" | jq -r '.vlan')
  user_tts["$name"]=$(echo "$line" | jq -r '.tunnel_type')
  user_tms["$name"]=$(echo "$line" | jq -r '.tunnel_medium_type')
done <<< "$(echo "$user_list" | jq -c '.data[]')"

# ======= Wiederverwendbare Funktion ========
send_user() {
  local method="$1"
  local url="$2"
  local json="$3"

  curl -sk -X "$method" "$url" \
    -H "Content-Type: application/json" \
    -H "x-csrf-token: $csrf_token" \
    -b "$COOKIE_FILE" \
    -d "$json" > /dev/null
}

# ======= Datei blockweise verarbeiten ========
echo "[*] Verarbeite Benutzerdaten..."

block=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  block+=("$line")

  if [[ ${#block[@]} -eq 6 ]]; then
    gateway_line="${block[0]//[$'\t\r\n']}"
    comment_line="${block[1]}"
    creds_line="${block[2]}"
    tunnel_type=$(echo "${block[3]}" | grep -oE '[0-9]+')
    tunnel_medium=$(echo "${block[4]}" | grep -oE '[0-9]+')
    vlan_id=$(echo "${block[5]}" | grep -oE '[0-9]+')

    username=$(echo "$creds_line" | awk '{print $1}')
    comment_clean=$(echo "$comment_line" | sed 's/^#\s*//' | xargs)
    clean_gateway_line=$(echo "$gateway_line" | sed 's/^#\s*//' | xargs)

    if ! echo "$clean_gateway_line" | grep -q "$local_gateway"; then
      echo "[-] Benutzer $username $comment_clean nicht für diesen Gateway ($local_gateway) vorgesehen. Überspringe."
      block=(); continue
    fi

    valid_users["$username"]=1

    if [[ -z "${user_ids[$username]:-}" ]]; then
      echo "[+] Erstelle neuen Benutzer: $username (VLAN $vlan_id) $comment_clean"
      payload="{\"name\":\"$username\",\"x_password\":\"$username\",\"tunnel_type\":$tunnel_type,\"tunnel_medium_type\":$tunnel_medium,\"vlan\":\"$vlan_id\"}"
      send_user POST "$CONTROLLER/proxy/network/api/s/$SITE/rest/account" "$payload"
    else
      current_vlan=${user_vlans[$username]}
      current_tt=${user_tts[$username]}
      current_tm=${user_tms[$username]}
      user_id=${user_ids[$username]}

      if [[ "$current_vlan" != "$vlan_id" || "$current_tt" != "$tunnel_type" || "$current_tm" != "$tunnel_medium" ]]; then
        echo "[~] Aktualisiere Benutzer: $username (VLAN $current_vlan → $vlan_id) $comment_clean"
        payload="{\"name\":\"$username\",\"tunnel_type\":$tunnel_type,\"tunnel_medium_type\":$tunnel_medium,\"vlan\":\"$vlan_id\"}"
        send_user PUT "$CONTROLLER/proxy/network/api/s/$SITE/rest/account/$user_id" "$payload"
      else
        echo "[=] Keine Änderung nötig für $username $comment_clean"
      fi
    fi

    block=()
  fi

done <<< "$user_data"

# ======= Veraltete Benutzer löschen ========
if [[ "$ENABLE_AUTO_DELETE" == true ]]; then
  echo "[*] Prüfe auf veraltete Benutzer..."
  
  users_deleted=false
  while IFS= read -r existing_username; do
    if [[ -z "${valid_users[$existing_username]:-}" ]]; then
      user_id="${user_ids[$existing_username]}"
      delete_response=""
      if ! delete_response=$(curl -sk -X DELETE "$CONTROLLER/proxy/network/api/s/$SITE/rest/account/$user_id" \
        -H "x-csrf-token: $csrf_token" \
        -b "$COOKIE_FILE"); then
        echo "[!] Fehler beim HTTP DELETE für Benutzer $existing_username"
        continue
      fi
      
      if echo "$delete_response" | grep -q '"rc":"ok"'; then
        echo "[×] Benutzer $existing_username erfolgreich gelöscht."
        users_deleted=true
      else
        echo "[!] Fehler beim Löschen von $existing_username – Antwort: $delete_response"
      fi
    fi
  done < <(printf "%s\n" "${!user_ids[@]}")
  
  if [ "$users_deleted" = false ]; then
    echo "[=] Keine veralteten Benutzer gefunden, nichts gelöscht."
  fi
else
  echo "[=] Automatische Löschung ist deaktiviert – keine veralteten Benutzer gelöscht."
fi
