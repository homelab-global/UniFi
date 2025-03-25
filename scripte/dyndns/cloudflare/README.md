Dieses Repository enthält ein Bash-Skript (`dyndns_cloudflare.sh`) zur automatischen Aktualisierung von DNS-Einträgen (IPv4 und/oder IPv6) für eine angegebene Subdomain in Cloudflare. Das Skript sorgt dafür, dass der DNS-Eintrag immer mit der aktuellen öffentlichen IP-Adresse übereinstimmt und erstellt automatisch neue Einträge, falls diese noch nicht vorhanden sind.

## Features
- **Mehrere Subdomains gleichzeitig aktualisieren.**
- **IPv4 und IPv6 Unterstützung**: Aktualisierung von `A`- und/oder `AAAA`-Einträgen.
- **Automatische Erstellung von Einträgen**: Fehlende DNS-Einträge werden automatisch angelegt.
- **Systemd-kompatibel**: Entwickelt für den Einsatz als systemd-Dienst mit Timer für periodische Updates.
- **Leichtgewichtige Implementierung**: Verwendung von Standardtools.

---

## Voraussetzungen

### Cloudflare API-Token
Ein API-Token mit den folgenden Berechtigungen wird benötigt:
- **Zone: Lesen**
- **DNS: Bearbeiten**

Das Token kann im [Cloudflare-Dashboard](https://dash.cloudflare.com/profile/api-tokens) erstellt werden.

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
curl -o /data/scripte/dyndns_cloudflare.sh https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/dyndns/cloudflare/dyndns_cloudflare.sh
chmod +x /data/scripte/dyndns_cloudflare.sh
curl -o /data/scripte/dyndns_cloudflare.conf https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/dyndns/cloudflare/dyndns_cloudflare.conf
chmod 600 /data/scripte/dyndns_cloudflare.conf
curl -o /data/scripte/dyndns_cloudflare.service https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/dyndns/cloudflare/dyndns_cloudflare.service
curl -o /data/scripte/dyndns_cloudflare.timer https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/dyndns/cloudflare/dyndns_cloudflare.timer

```

### Schritt 3: Konfiguration anpassen
Bearbeiten Sie die Datei `dyndns_cloudflare.conf`:
```bash
# Cloudflare API-Token
API_TOKEN="dein_api_token"

# Liste der zu aktualisierenden Subdomains mit DNS-Typen und Proxy-Status
# Format: "Subdomain DNS-Typen (A oder AAAA oder A,AAAA) Proxy (true/false)"
"sub1.example.com A false"
"sub2.example.net AAAA false"
"sub3.example.org A,AAAA false"

# TTL-Wert für alle DNS-Einträge
TTL=60
```

### Schritt 4: Systemd konfigurieren
Verlinke die heruntergeladenen Dateien ins Systemd-Verzeichnis:
```bash
ln -s /data/scripte/dyndns_cloudflare.service /etc/systemd/system/dyndns_cloudflare.service
ln -s /data/scripte/dyndns_cloudflare.timer /etc/systemd/system/dyndns_cloudflare.timer
```

### Schritt 5: Dienst aktivieren und starten
Aktualisiere die Systemd-Konfiguration und aktiviere den Timer:
```bash
systemctl daemon-reload
systemctl enable dyndns_cloudflare.timer
systemctl start dyndns_cloudflare.timer
```

---

## Verwendung

### Status und Logs prüfen
- **Timer-Status anzeigen**:
  ```bash
  systemctl status dyndns_cloudflare.timer
  ```

- **Dienst-Status anzeigen**:
  ```bash
  systemctl status dyndns_cloudflare.service
  ```

- **Logs anzeigen**:
  ```bash
  journalctl -u dyndns_cloudflare.service
  ```

---

## Lizenz
Dieses Projekt wird unter der MIT-Lizenz veröffentlicht. Weitere Informationen findest du in der Datei [LICENSE](https://github.com/homelab-global/UniFi/blob/main/LICENSE).

---

## Beiträge
Beiträge und Verbesserungen sind herzlich willkommen! Erstelle ein [Issue](https://github.com/homelab-global/UniFi/issues) oder sende einen [Pull Request](https://github.com/homelab-global/UniFi/pulls) ein.
