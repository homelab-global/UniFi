# DynDNS Aktualisierungsskript für Cloudflare

Dieses Repository enthält ein Bash-Skript (`dyndns_cloudflare.sh`), um DNS-Einträge (IPv4 und/oder IPv6) für eine angegebene Subdomain in Cloudflare zu aktualisieren. Das Skript sorgt dafür, dass der DNS-Eintrag mit der aktuellen öffentlichen IP-Adresse aktualisiert wird und erstellt automatisch den DNS-Eintrag, falls dieser noch nicht existiert.

## Funktionen
- Unterstützt sowohl IPv4 (`A`-Einträge) als auch IPv6 (`AAAA`-Einträge).
- Erstellt automatisch fehlende DNS-Einträge.
- Entwickelt für den Einsatz als systemd-Dienst mit Timer für periodische Updates.
- Leichtgewichtig und nutzt nur Standardtools wie `curl`, `awk` und `grep`.

---

## Voraussetzungen

### 1. Cloudflare API-Token
Du benötigst ein Cloudflare API-Token mit folgenden Berechtigungen:
- **Zone: Lesen**
- **DNS: Bearbeiten**

Erstelle ein API-Token über das [Cloudflare-Dashboard](https://dash.cloudflare.com/profile/api-tokens).

### 2. Systemanforderungen
- Ein Linux-System mit:
  - `curl`
  - `awk`
  - `grep`

---

## Installation

### 1. Dateien herunterladen
Lade die folgenden Dateien mit `curl` herunter und verschiebe sie nach `/data/scripte`:

#### /data/scripte anlegen wenn noch nicht vorhanden
```bash
mkdir -p /data/scripte
```

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

### 2. Dateien mit Systemd verlinken
Verlinke die heruntergeladenen Dateien in das Systemd-Verzeichnis:
```bash
sudo ln -s /data/scripte/dyndns_cloudflare.service /etc/systemd/system/dyndns_cloudflare.service
sudo ln -s /data/scripte/dyndns_cloudflare.timer /etc/systemd/system/dyndns_cloudflare.timer
```

### 3. Dienst und Timer aktivieren
Lade die Systemd-Daemon-Konfiguration neu und aktiviere den Timer:
```bash
sudo systemctl daemon-reload
sudo systemctl enable dyndns_cloudflare.timer
sudo systemctl start dyndns_cloudflare.timer
```

---

## Verwendung

Der Dienst aktualisiert die DNS-Einträge automatisch alle 5 Minuten (Standard). Um das Skript manuell auszuführen, verwende:

```bash
/data/scripte/dyndns_cloudflare.sh
```

### Status überprüfen
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

## Skript-Konfiguration

Die folgenden Variablen in `dyndns_cloudflare.sh` müssen angepasst werden:

- `API_TOKEN`: Dein Cloudflare API-Token.
- `RECORD_NAME`: Die Subdomain, die aktualisiert werden soll (z. B. `subdomain.example.com`).
- `DNS_TYPES`: Gibt an, welche DNS-Eintragstypen aktualisiert werden (z. B. `("A" "AAAA")` für sowohl IPv4 als auch IPv6).
- `TTL`: Die Time-To-Live für den DNS-Eintrag (z. B. `60` für auto-managed).
- `PROXIED`: Ob Cloudflare’s Proxy aktiviert wird (`true` oder `false`).

---

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe die [LICENSE](LICENSE)-Datei für Details.

---

## Beitragen

Beiträge sind willkommen! Erstelle gerne Issues oder sende Pull Requests.

---

## Danksagungen

- [Cloudflare API-Dokumentation](https://developers.cloudflare.com/api/)
- Community-Ressourcen und Anleitungen für DynDNS-Updates.
