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
| Adresse | `<HOST-IP>` |
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

## 4. Externe Erreichbarkeit über DuckDNS + FritzBox (DS-Lite / IPv6)

> ⚠️ Mit dieser Konfiguration ist Port 64738 direkt aus dem Internet erreichbar.
> Mumble verschlüsselt alle Inhalte (DTLS/SRTP). Schutz erfolgt durch starkes
> Serverpasswort + ACL. Das restliche Heimnetz bleibt vollständig isoliert –
> nur Port 64738 ist weitergeleitet.

> **DS-Lite-Hinweis:** Bei DS-Lite gibt es keine öffentliche IPv4-Adresse.
> Externe Clients verbinden sich ausschließlich über IPv6. Die IPv6 des Hosts
> wird per DuckDNS-Skript alle 5 Minuten aktualisiert. IPv4-Portfreigaben in
> der FritzBox sind wirkungslos – stattdessen wird eine IPv6-Firewall-Freigabe
> benötigt.

### 4.1 DuckDNS Dynamic DNS (automatisch)

**Mumble-Adresse:** `m3mumble.duckdns.org`  
**Skript:** `~/docker/mumble/duckdns/update.sh`  
**Cron:** alle 5 Minuten, Log → `~/docker/mumble/duckdns/duckdns.log`

Das Skript ermittelt die globale IPv6-Adresse des Interface `ens18` (Präfix `2a02:`)
und ruft die DuckDNS-API auf. Das `duckdns/`-Verzeichnis ist in `.gitignore` –
Token und Log werden nicht eingecheckt.

**Einmalig einrichten (nach Neuinstallation):**

```bash
# Ausführbar machen
chmod +x ~/docker/mumble/duckdns/update.sh

# Cron-Job eintragen
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/andreas/docker/mumble/duckdns/update.sh >> /home/andreas/docker/mumble/duckdns/duckdns.log 2>&1") | crontab -

# Einmalig manuell ausführen
~/docker/mumble/duckdns/update.sh
cat ~/docker/mumble/duckdns/duckdns.log
# Erwartete Ausgabe: ...IPv6=2a02:... response=OK

# DNS-Auflösung prüfen
dig AAAA m3mumble.duckdns.org +short
```

### 4.2 IPv6-Firewall-Freigabe in der FritzBox (FritzBox 6660 Cable)

**http://fritz.box → Heimnetz → Netzwerk → (Gerät auswählen) → IPv6-Adressen**

Dort die aktuelle IPv6-Adresse des Hosts notieren.

**http://fritz.box → Internet → Freigaben → Portfreigaben**

**„Gerät für Freigaben hinzufügen"** → Geekom A8 Max auswählen.

Dann **„Neue Freigabe"** → **„Portfreigabe"**:

Erste Regel (TCP):

| Feld | Wert |
|---|---|
| Anwendung | Andere Anwendung |
| Protokoll | TCP |
| Port an Gerät | 64738 |
| bis Port | 64738 |
| Port extern gewünscht | 64738 |
| Internetzugriff | **IPv6** (nicht IPv4 – DS-Lite!) |

→ OK, dann nochmal **„Neue Freigabe"** → identisch, aber Protokoll **UDP**.

Ergebnis: 2 Einträge (TCP + UDP für IPv6).

> **Warum kein IPv4?** Bei DS-Lite teilen sich viele Haushalte eine IPv4-Adresse
> über CGNAT – eingehende IPv4-Verbindungen von außen sind nicht möglich.
> Nur IPv6 funktioniert für externe Erreichbarkeit.

**Nicht anklicken:**
- ❌ „Exposed Host" (IPv4 oder IPv6)
- ❌ „Selbstständige Portfreigaben erlauben"

### 4.3 Docker IPv6-Support aktivieren (einmalig auf dem Host)

`daemon.json` liegt im Repo als `daemon.json` und muss nach `/etc/docker/` kopiert werden:

```bash
# daemon.json einspielen
sudo cp ~/docker/mumble/daemon.json /etc/docker/daemon.json

# Docker-Daemon neu starten (alle Container stoppen kurz, starten automatisch neu)
sudo systemctl restart docker

# Mumble-Container mit IPv6-Netzwerk neu anlegen (--force-recreate nötig nach erstem Setup)
cd ~/docker/mumble && docker compose up -d --force-recreate

# Verifizieren
docker compose ps
# STATUS sollte "healthy" zeigen und Ports: 0.0.0.0:64738->64738, [::]:64738->64738
docker inspect mumble --format '{{json .NetworkSettings.Ports}}'
# Muss für tcp und udp je zwei Einträge zeigen: HostIp 0.0.0.0 und HostIp ::
```

> **Hinweis `userland-proxy: false`:** Docker startet keinen `docker-proxy`-Prozess,
> sondern setzt nftables-DNAT-Regeln. Direkt nach dem Daemon-Neustart kann `docker inspect`
> kurz nur IPv4 zeigen — das ist ein transienter Zustand, der sich nach wenigen Sekunden
> selbst auflöst. Bei anhaltenden Problemen: `docker compose up -d --force-recreate`.

### 4.4 Firewall-Check

**http://fritz.box → Internet → Freigaben → Portfreigaben → Gerät bearbeiten**

Die zwei Mumble-Regeln (TCP + UDP, jeweils IPv6) sollten dort stehen.

**http://fritz.box → Internet → Freigaben → „Exposed Host"**

Hier darf **kein** Gerät eingetragen sein.

### 4.5 Externe Clients verbinden

#### Desktop (Windows/macOS/Linux)

Mumble herunterladen: https://www.mumble.info/downloads/

Server hinzufügen:

| Feld | Wert |
|---|---|
| Adresse | `m3mumble.duckdns.org` |
| Port | `64738` |
| Benutzername | Gewünschter Anzeigename |
| Passwort | Inhalt von `secrets/MUMBLE_CONFIG_serverpassword` |

#### Android: Mumla

Mumla im Play Store installieren: **Mumla – Mumble client**

Server hinzufügen (Plus-Symbol):

| Feld | Wert |
|---|---|
| Label | Familien-Sprechanlage (frei wählbar) |
| Address | `m3mumble.duckdns.org` |
| Port | `64738` |
| Username | Gewünschter Anzeigename |
| Password | Inhalt von `secrets/MUMBLE_CONFIG_serverpassword` |

Beim ersten Verbinden: SSL-Warnung → Zertifikat akzeptieren (selbstsigniert, normal).  
Danach: **Selbst → Registrieren** — verknüpft den Namen dauerhaft mit dem Gerät
und schaltet `@auth`-Rechte (Sprechen) frei.

> **IPv6-Hinweis:** Über LTE/5G funktioniert die Verbindung direkt. Im Heimnetz
> nur wenn der Router IPv6 unterstützt; alternativ `mumble.home` per Pi-hole
> (siehe 4.6).

### 4.6 Pi-hole (optional: LAN-Zugriff via Hostname)

Externe Clients nutzen DuckDNS direkt — Pi-hole ist nicht beteiligt.

Falls interne Clients ebenfalls über `m3mumble.duckdns.org` verbinden wollen
(statt direkt über die LAN-IP), und das IPv6-Hairpinning der FritzBox nicht
funktioniert:

**http://pi.hole → Local DNS → DNS Records**

| Domain | IP |
|---|---|
| `mumble.home` | IPv6-Adresse des Hosts (aus FritzBox-Netzwerkübersicht) |

Dann können interne Clients `mumble.home:64738` nutzen.

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
    "<HOST-IP>", "kind",
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
- IPv6 erfordert `ip6tables: true` in `/etc/docker/daemon.json` und ein Netz mit `enable_ipv6: true` im Compose-File — ohne beides bindet Docker keinen `[::]`-Port

---

*Erstellt März 2026 · Geekom A8 Max + Docker + FritzBox + DuckDNS · mumble.info*