Dieses Repository enthält ein Bash-Skript (`dyndns_cloudflare.sh`), um DNS-Einträge (IPv4 und/oder IPv6) für eine angegebene Subdomain in Cloudflare zu aktualisieren. Das Skript sorgt dafür, dass der DNS-Eintrag mit der aktuellen öffentlichen IP-Adresse aktualisiert wird und erstellt automatisch den DNS-Eintrag, falls dieser noch nicht existiert.

## Funktionen
- Unterstützt sowohl IPv4 (`A`-Einträge) als auch IPv6 (`AAAA`-Einträge).
- Erstellt automatisch fehlende DNS-Einträge.
- Entwickelt für den Einsatz als systemd-Dienst mit Timer für periodische Updates.
- Leichtgewichtig und nutzt nur Standardtools wie `curl`, `awk` und `grep`.

## Voraussetzungen

### Cloudflare API-Token
Du benötigst ein Cloudflare API-Token mit folgenden Berechtigungen:
- **Zone: Lesen**
- **DNS: Bearbeiten**

Erstelle ein API-Token über das [Cloudflare-Dashboard](https://dash.cloudflare.com/profile/api-tokens).

---

## Installation

### 1. Ordner erstellen
Erstelle den Zielordner für das Skript:
```bash
mkdir -p /data/scripte
```

### 2. Dateien herunterladen
Lade die benötigten Dateien mit `curl` herunter:

#### Skript herunterladen
```bash
curl -o /data/scripte/dyndns_cloudflare.sh https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/dyndns/cloudflare/dyndns_cloudflare.sh
chmod +x /data/scripte/dyndns_cloudflare.sh
```

#### Dienst-Datei herunterladen
```bash
curl -o /data/scripte/dyndns_cloudflare.service https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/dyndns/cloudflare/dyndns_cloudflare.service
```

#### Timer-Datei herunterladen
```bash
curl -o /data/scripte/dyndns_cloudflare.timer https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/dyndns/cloudflare/dyndns_cloudflare.timer
```

### 3. Script anpassen
Die folgenden Variablen in `dyndns_cloudflare.sh` müssen angepasst werden:

- `API_TOKEN`: Dein Cloudflare API-Token.
- `RECORD_NAME`: Die Subdomain, die aktualisiert werden soll (z. B. `subdomain.example.com`).
- `DNS_TYPES`: Gibt an, welche DNS-Eintragstypen aktualisiert werden (z. B. `("A" "AAAA")` für sowohl IPv4 als auch IPv6).
- `TTL`: Die Time-To-Live für den DNS-Eintrag (z. B. `60` für auto-managed).
- `PROXIED`: Ob Cloudflare’s Proxy aktiviert wird (`true` oder `false`)

### 4. Dateien mit Systemd verknüpfen
Verlinke die heruntergeladenen Dateien ins Systemd-Verzeichnis:
```bash
ln -s /data/scripte/dyndns_cloudflare.service /etc/systemd/system/dyndns_cloudflare.service
ln -s /data/scripte/dyndns_cloudflare.timer /etc/systemd/system/dyndns_cloudflare.timer
```

### 5. Dienst aktivieren und starten
Lade die Systemd-Konfiguration neu und aktiviere den Dienst:
```bash
systemctl daemon-reload
systemctl enable dyndns_cloudflare.timer
systemctl start dyndns_cloudflare.timer
```

---

## Verwendung

-

### Status und Logs

- Timer-Status:
  ```bash
  systemctl status dyndns_cloudflare.timer
  ```

- Dienst-Status:
  ```bash
  systemctl status dyndns_cloudflare.service
  ```

- Logs:
  ```bash
  journalctl -u dyndns_cloudflare.service
  ```

---

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Weitere Details findest du in der Datei [LICENSE](https://github.com/homelab-global/UniFi/blob/main/LICENSE).

---

## Beiträge

Beiträge sind herzlich willkommen! Erstelle gerne ein Issue oder sende einen Pull Request ein.
