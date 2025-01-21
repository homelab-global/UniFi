Dieses Repository bietet ein Bash-Skript (`add_ssh_key.sh`) zum einfachen und automatisierten Hinzufügen mehrerer SSH-Keys zur Datei `authorized_keys` eines UniFi-Systems.

## Funktionen
- Automatische Erstellung der Datei `authorized_keys`, falls diese nicht existiert.
- Überprüfung, ob ein SSH-Key bereits vorhanden ist, bevor er hinzugefügt wird, um Duplikate zu vermeiden.

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
curl -o /data/scripte/add_ssh_key.sh https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/add_ssh_key/add_ssh_key.sh
chmod +x /data/scripte/add_ssh_key.sh
```

#### Dienst-Datei herunterladen
```bash
curl -o /data/scripte/add_ssh_key.service https://raw.githubusercontent.com/homelab-global/UniFi/refs/heads/main/scripte/add_ssh_key/add_ssh_key.service
```

### 3. Dienst-Datei anpassen
Passe in der Datei `/data/scripte/add_ssh_key.service` den Parameter `ExecStart` an, um die gewünschten SSH-Keys zu definieren. Beispiel:
```bash
ExecStart=/data/scripte/add_ssh_keys.sh "ssh-rsa AAAAB3..." "ssh-ed25519 BBBB44..."
```

### 4. Dateien mit Systemd verknüpfen
Verlinke die heruntergeladenen Dateien ins Systemd-Verzeichnis:
```bash
ln -s /data/scripte/add_ssh_key.service /etc/systemd/system/add_ssh_key.service
```

### 5. Dienst aktivieren und starten
Lade die Systemd-Konfiguration neu und aktiviere den Dienst:
```bash
systemctl daemon-reload
systemctl enable add_ssh_key.service
systemctl start add_ssh_key.service
```

---

## Verwendung

-

### Status und Logs

- Status des Dienstes prüfen:
  ```bash
  systemctl status add_ssh_key.service
  ```

- Logs einsehen:
  ```bash
  journalctl -u add_ssh_key.service
  ```

---

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Weitere Details findest du in der Datei [LICENSE](LICENSE).

---

## Beiträge

Beiträge sind herzlich willkommen! Erstelle gerne ein Issue oder sende einen Pull Request ein.
