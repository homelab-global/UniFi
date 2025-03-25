Dieses Repository enthält ein Bash-Skript (`sync_radius_users.sh`) zur automatischen Synchronisierung von FreeRADIUS Usern auf UniFI Gateways die mittels UniFi API dem UniFi Controller hinzugefügt/geändert/gelöscht werden.

## Features
- Zentrale Verwaltung von FreeRADIUS auf Github
- Unterstützung von meheren UniFI Gateways
- Es überprüft, ob die User Datei auf Github aktualisiert wurde, lädt die Datei herunter und füght neue User hinzu, bearbeitet vorhande User oder löscht User die sich nicht mehr in der User Datei befinden.

---

## Voraussetzungen

- Github Token - Ein persönliches Zugriffstoken (PAT) für den Zugriff auf das GitHub-Repository.
- Ein UniFi Controller mit Administratorzugang.
- Ein GitHub-Repository, die die Benutzerkonfigurationsdatei enthält.

---

## Installation

### Schritt 1: Zielordner erstellen
Erstelle einen Ordner für das Skript:
```bash
mkdir -p /data/scripte
```

### Schritt 2: Dateien herunterladen
Lade die benötigten Dateien herunter und stelle sicher, dass sie ausführbar sind:

```bash
curl -o /data/scripte/dyndns_cloudflare.sh https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/sync_radius_users/sync_radius_users.sh
chmod +x /data/scripte/sync_radius_users.sh
curl -o/data/scripte/dyndns_cloudflare.service https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/sync_radius_users/sync_radius_users.service
curl -o /data/scripte/dyndns_cloudflare.timer https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/sync_radius_users/sync_radius_users.timer

```

### Schritt 3: Benutzerkonfigurationsdatei (users)

```bash
# UniFi Gateway Name
# Kommentar
Username Cleartext-Password := "Passwort"
        Tunnel-Type             = 13,
        Tunnel-Medium-Type      = 6,
        Tunnel-Private-Group-Id = x

# UniFi Gateway Name, UniFi Gateway Name 1
# Kommentar
Username Cleartext-Password := "Passwort"
        Tunnel-Type             = 13,
        Tunnel-Medium-Type      = 6,
        Tunnel-Private-Group-Id = x
```

### Schritt 3: Konfiguration anpassen
```bash
# ======= Konfiguration ========
CONTROLLER="https://127.0.0.1:443"
USERNAME="admin"
PASSWORD="..."
SITE="default"
COOKIE_FILE="cookie.txt"

# ======= GitHub Repo + Token (privat) ========
GITHUB_TOKEN="ghp_..."
RAW_URL="https://api.github.com/repos/..."
HASH_FILE="/tmp/sync_radius_users.hash"

# ======= Optionen ========
ENABLE_AUTO_DELETE=true
```

### Schritt 4: Systemd konfigurieren
Verlinke die heruntergeladenen Dateien ins Systemd-Verzeichnis:
```bash
ln -s /data/scripte/sync_radius_users.service /etc/systemd/system/sync_radius_users.service
ln -s /data/scripte/sync_radius_users.timer /etc/systemd/system/sync_radius_users.timer
```

### Schritt 5: Dienst aktivieren und starten
Aktualisiere die Systemd-Konfiguration und aktiviere den Timer:
```bash
systemctl daemon-reload
systemctl enable sync_radius_users.timer
systemctl start sync_radius_users.timer
```

---

## Verwendung

### Status und Logs prüfen
- **Timer-Status anzeigen**:
  ```bash
  systemctl status sync_radius_users.timer
  ```

- **Dienst-Status anzeigen**:
  ```bash
  systemctl status sync_radius_users.service
  ```

- **Logs anzeigen**:
  ```bash
  journalctl -u sync_radius_users.service
  ```

---

## Lizenz
Dieses Projekt wird unter der MIT-Lizenz veröffentlicht. Weitere Informationen findest du in der Datei [LICENSE](https://github.com/homelab-global/UniFi/blob/main/LICENSE).

---

## Beiträge
Beiträge und Verbesserungen sind herzlich willkommen! Erstelle ein [Issue](https://github.com/homelab-global/UniFi/issues) oder sende einen [Pull Request](https://github.com/homelab-global/UniFi/pulls) ein.
