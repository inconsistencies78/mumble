# Mumble Server – Setup & Betriebsanleitung

**Zweck:** Geschlossener Sprachkommunikations-Server für Familie und kleinen Freundeskreis  
**Max. User:** 10 | **Stack:** Docker Compose | **Port:** 64738 TCP+UDP  
**Externer Zugang:** FritzBox + MyFRITZ! DynDNS  
**Stand:** März 2026 · getestet auf Ubuntu 24.04 + Docker 29.3

---

## Verzeichnisstruktur

```
~/docker/mumble/
├── docker-compose.yml
├── .env                ← Nur Kommentare, keine Passwörter
├── secrets/            ← Passwörter (chmod 700, nie in Git!)
│   ├── MUMBLE_SUPERUSER_PASSWORD
│   └── MUMBLE_CONFIG_serverpassword
├── backup.sh           ← Backup-Skript (via Cron)
├── backups/            ← SQLite-Backups (automatisch angelegt)
└── (mumble_data/       → Docker Volume, automatisch angelegt)
```

---

## 1. Erster Start

### 1.1 Passwörter setzen

Passwörter liegen **nicht** in `.env`, sondern in separaten Dateien unter `secrets/`
(Docker Secrets – sicherer als Umgebungsvariablen, nicht über `docker inspect` auslesbar).

```bash
cd ~/docker/mumble

# Verzeichnis anlegen (falls nicht vorhanden)
mkdir -p secrets backups
chmod 700 secrets

# Passwörter generieren und direkt in die Dateien schreiben
openssl rand -base64 18 > secrets/MUMBLE_SUPERUSER_PASSWORD   # Admin (SuperUser)
openssl rand -base64 18 > secrets/MUMBLE_CONFIG_serverpassword # Serverpasswort
chmod 600 secrets/MUMBLE_SUPERUSER_PASSWORD secrets/MUMBLE_CONFIG_serverpassword
```

Beide Werte sofort in **KeePass** speichern:
```bash
cat secrets/MUMBLE_SUPERUSER_PASSWORD
cat secrets/MUMBLE_CONFIG_serverpassword
```

### 1.2 Container starten

```bash
cd ~/docker/mumble
docker compose up -d
docker compose logs -f
```

Erwartete Ausgabe:
```
1 => Server listening on 0.0.0.0:64738
```

---

## 2. Erstkonfiguration im Mumble-Client (einmalig)

### 2.1 Als SuperUser verbinden

Mumble-Client herunterladen: https://www.mumble.info/downloads/

Server hinzufügen:

| Feld | Wert |
|---|---|
| Adresse | `192.168.178.12` |
| Port | `64738` |
| Benutzername | `SuperUser` |
| Passwort | Inhalt von `secrets/MUMBLE_SUPERUSER_PASSWORD` |

Beim Verbinden: Serverpasswort = Inhalt von `secrets/MUMBLE_CONFIG_serverpassword`  
SSL-Warnung beim ersten Mal → Zertifikat akzeptieren und speichern (selbstsigniert, normal).

### 2.2 Channels anlegen

Rechtsklick auf Root-Channel „Familien-Sprechanlage" → „Kanal hinzufügen":

```
Familien-Sprechanlage
├── Familie
├── Freundinnen
└── Notfall
```

### 2.3 Zugriffsrechte (ACL) setzen

Rechtsklick auf „Familien-Sprechanlage" → „Zugriffsrechte bearbeiten (ACL)" → Tab „Berechtigungen":

**`@all` auswählen:**
- Betreten → Verweigern
- Sprechen → Verweigern
- Selbst registrieren → Erlauben (stehen lassen)

**`@auth` auswählen:**
- Betreten → Erlauben
- Sprechen → Erlauben
- Flüstern → Erlauben
- Zuhören → Erlauben

→ **OK**

---

## 3. User anlegen

### Ablauf für jeden neuen User

1. User verbindet sich mit beliebigem Benutzernamen + Serverpasswort
2. Im Mumble-Client des Users: **Selbst → Registrieren**  
   → Name wird dauerhaft mit dem Client-Zertifikat verknüpft
3. User ist jetzt `@auth` und kann sprechen

### Unerwünschte User entfernen

Als SuperUser: Rechtsklick auf User → „Kicken" (temporär) oder „Bannen" (dauerhaft)  
Registrierung löschen: Rechtsklick → „Registrierung aufheben"

---

## 4. Externe Erreichbarkeit über FritzBox + MyFRITZ!

> ⚠️ Mit dieser Konfiguration ist Port 64738 direkt aus dem Internet erreichbar.
> Mumble verschlüsselt alle Inhalte (DTLS/SRTP). Schutz erfolgt durch starkes
> Serverpasswort + ACL. Das restliche Heimnetz bleibt vollständig isoliert –
> nur Port 64738 ist weitergeleitet.

### 4.1 Portweiterleitung in der FritzBox (FritzBox 6660 Cable)

**http://fritz.box → Internet → Freigaben → Portfreigaben**

**„Gerät für Freigaben hinzufügen"** → `proxmox-ubuntu` (192.168.178.12) auswählen.

Dann **„Neue Freigabe"** → **„Portfreigabe"** (nicht „MyFRITZ!-Freigabe"):

Erste Regel (TCP):

| Feld | Wert |
|---|---|
| Anwendung | Andere Anwendung |
| Protokoll | TCP |
| Port an Gerät | 64738 |
| bis Port | 64738 |
| Port extern gewünscht | 64738 |
| Internetzugriff | IPv4 und IPv6 |

→ OK, dann nochmal **„Neue Freigabe"** → identisch, aber Protokoll **UDP**.

Ergebnis: 4 grüne Einträge (TCP+UDP je für IPv4 und IPv6 – automatisch, nicht löschen).

**Nicht anklicken:**
- ❌ „Exposed Host" (IPv4 oder IPv6)
- ❌ „Selbstständige Portfreigaben erlauben"

### 4.2 MyFRITZ!-Adresse einrichten

**http://fritz.box → Internet → MyFRITZ!-Konto**

Nach Einrichtung erscheint die feste Adresse, z.B.:
```
abc12345.myfritz.net
```

### 4.3 Firewall-Check

**http://fritz.box → Internet → Freigaben → Portfreigaben → Gerät bearbeiten**

Ausschließlich die vier Mumble-Regeln (2× TCP, 2× UDP) sollten dort stehen.

**http://fritz.box → Internet → Freigaben → „Exposed Host"**

Hier darf **kein** Gerät eingetragen sein.

### 4.4 Externe Clients verbinden

```
Adresse: abc12345.myfritz.net
Port:    64738
```

---

## 5. Kinderprojekt – Raspberry Pi Integration

`pymumble` ermöglicht programmatischen Mumble-Zugang vom Pi:

```bash
pip install pymumble-py3 pyaudio RPi.GPIO
```

Minimales PTT-Beispiel (GPIO-Button):

```python
import pymumble_py3 as pymumble

mumble = pymumble.Mumble(
    "192.168.178.12", "kind",
    port=64738,
    password="SERVER_PASSWORT"
)
mumble.start()
mumble.is_ready()
# Audio-Aufnahme + GPIO: siehe https://github.com/azlux/pymumble
```

---

## 6. Ressourcenverbrauch (Geekom A8 Max)

| Ressource | Idle | 5 Sprecher | 10 Sprecher |
|---|---|---|---|
| CPU | < 0,5 % | ~1–2 % | ~2–4 % |
| RAM | ~20 MB | ~25 MB | ~30 MB |
| Netzwerk upstream | ~0 kbit/s | ~160 kbit/s | ~320 kbit/s |

---

## 7. Backup

### 7.1 Automatisches Backup via Cron (empfohlen)

Das Skript `backup.sh` sichert die SQLite-Datenbank täglich und löscht Backups
die älter als 30 Tage sind.

```bash
# Einmalig einrichten
crontab -e
```

Folgende Zeile eintragen (täglich um 03:00 Uhr):
```
0 3 * * * /home/andreas/docker/mumble/backup.sh >> /home/andreas/docker/mumble/backups/backup.log 2>&1
```

### 7.2 Manuelles Backup

```bash
cd ~/docker/mumble
./backup.sh
```

### 7.3 Wiederherstellen

```bash
# Container stoppen
docker compose stop mumble

# Backup einspielen (DATUM anpassen)
docker run --rm \
  -v mumble_mumble_data:/data \
  -v $(pwd)/backups:/backup \
  alpine sh -c "cp /backup/mumble_DATUM.sqlite /data/mumble-server.sqlite"

docker compose start mumble
```

---

## 8. Nützliche Befehle

```bash
# Status
docker compose ps

# Logs
docker compose logs -f mumble

# Neustart
docker compose restart mumble

# SuperUser-Passwort ändern
# → Neues Passwort in secrets/MUMBLE_SUPERUSER_PASSWORD schreiben, dann:
# WICHTIG: Kein -v! Das würde das Volume (Datenbank!) löschen.
docker compose down && docker compose up -d

# Image aktualisieren
docker compose pull && docker compose up -d
```

---

## 9. Bekannte Eigenheiten des Images

- Konfiguration über Umgebungsvariablen (`MUMBLE_CONFIG_*`) **oder** Docker Secrets (`secrets/MUMBLE_CONFIG_*`) – wir nutzen Secrets
- `command: ["mumble-server", "-fg"]` ist zwingend erforderlich – ohne `-fg` beendet sich der Prozess sofort mit Code 0
- `config/mumble.ini` im Repo ist ein leeres Verzeichnis (Docker-Artefakt) – hat keinen Effekt, da im Compose-File nicht eingebunden
- Bandwidth-Limit 32 kbit/s pro User ist bewusst niedrig (Upload-Schonung bei FritzBox-Anschluss); Mumble-Standard wäre 72 kbit/s

---

*Erstellt März 2026 · Geekom A8 Max + Docker + FritzBox MyFRITZ! · mumble.info*