Dieses Repository stellt ein professionelles Bash-Skript und einen systemd-Dienst zur Verfügung, mit dem MACVLAN-Schnittstellen verwaltet werden können, um den Zugriff auf ein Modem über WAN-Interfaces zu ermöglichen. Das Skript unterstützt die Konfiguration mehrerer Interfaces, Es unterstützt sowohl vordefinierte Modemkonfigurationen als auch manuelle Einträge direkt in der Konfigurationsdatei.

## Funktionen
- **Unterstützung mehrerer Interfaces**: Effiziente Verwaltung und Konfiguration von MACVLAN-Interfaces.
- **Dynamische Konfiguration**: Einfache Definition von WAN-Interfaces, lokalen IPs und Modem-IPs über eine Konfigurationsdatei.
- **Manuelle Konfiguration**: Individuelle Modems lassen sich direkt in modem_access.conf angeben.
- **Vordefinierte Modemkonfigurationen**: Modems können in der Datei modem_access.db definiert werden.
- **Automatische NAT-Einrichtung**: Verwaltung von iptables-NAT-Regeln für reibungslosen Zugriff.
- **Fehlerbehandlung**: Ausführliche Rückmeldungen bei Konfigurationsproblemen.
- **Systemd-Dienstintegration**: Nahtlose Steuerung von Start und Stopp des Skripts.

---

## Installation

### 1. Zielordner erstellen
Erstellen Sie den Zielordner für das Skript:
```bash
mkdir -p /data/scripte
```

### 2. Dateien herunterladen
Laden Sie die benötigten Dateien mit `curl` herunter:

#### Skript herunterladen
```bash
curl -o /data/scripte/modem_access.sh https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/modem_access/modem_access.sh
chmod +x /data/scripte/modem_access.sh
```

#### Dienst-Datei herunterladen
```bash
curl -o /data/scripte/modem_access.service https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/modem_access/modem_access.service
```

#### Konfigurationsdatei herunterladen
```bash
curl -o /data/scripte/modem_access.conf https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/modem_access/modem_access.conf
curl -o /data/scripte/modem_access.db https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/modem_access/modem_access.db

```

### 3. Konfiguration anpassen
Bearbeiten Sie die Datei `modem_access.conf`, um Ihre Schnittstellen zu definieren:

```ini
# Konfigurationsdatei für modem_access.sh
# Format Vordefiniertes Modem: <WAN_INTERFACE>,<MODEM_NAME>
# Beispieleintrag
# Vordefiniertes Modem
# eth4,Telekom_Glasfasermodem_2
# 
# Manuelles Modem: <WAN_INTERFACE>,<MODEM_IP>,<LOKALE_IP>
# Beispieleintrag
# eth4,192.168.1.2,192.168.1.1
# eth5,192.168.2.2,192.168.2.1
```

```ini
# Datei für vordefinierte Modemkonfigurationen
# Format: <MODEM_NAME>,<MODEM_IP>,<LOKALE_IP>
Telekom_Glasfasermodem_2,192.168.100.1,192.168.100.254
```

### 4. Dateien mit Systemd verknüpfen
Verlinken Sie die heruntergeladenen Dateien ins Systemd-Verzeichnis:
```bash
ln -s /data/scripte/modem_access.service /etc/systemd/system/modem_access.service
```

### 5. Dienst aktivieren und starten
Laden Sie die Systemd-Konfiguration neu und aktivieren Sie den Dienst:
```bash
systemctl daemon-reload
systemctl enable modem_access.service
systemctl start modem_access.service
```

---

## Verwendung

Das Skript und der Dienst können über Systemd gesteuert werden:

### Starten der Konfiguration
```bash
sudo systemctl start modem_access.service
```

### Stoppen der Konfiguration
```bash
sudo systemctl stop modem_access.service
```

### Status und Logs anzeigen

- **Dienststatus anzeigen**:
  ```bash
  systemctl status modem_access.service
  ```

- **Logs anzeigen**:
  ```bash
  journalctl -u modem_access.service
  ```

---

## Lizenz
Dieses Projekt wird unter der MIT-Lizenz veröffentlicht. Weitere Informationen findest du in der Datei [LICENSE](https://github.com/homelab-global/UniFi/blob/main/LICENSE).

---

## Beiträge
Beiträge und Verbesserungen sind herzlich willkommen! Erstelle ein [Issue](https://github.com/homelab-global/UniFi/issues) oder sende einen [Pull Request](https://github.com/homelab-global/UniFi/pulls) ein.
