# Otthoni szerver kiépítési roadmap (IaC alapon)

**Cél:** egy Ubuntu Server VM (Proxmoxon, Terraform+Ansible-lel felépítve), ami egyszerre jó otthoni szerver (média, könyvek, torrent, fotók) és szoftverfejlesztési környezet (Git, adatbázisok, konténerkezelés) — minden szolgáltatás Dockerben, a Webmin kivételével.

Ez a roadmap **ráépül** a korábban véglegesített 5 fázisos DevOps tanulási roadmapre és a már elkészült Terraform+Ansible vázra. A sorrend úgy van kialakítva, hogy minden fázis a előzőre épüljön, és a kritikus alaprendszer (hálózat, reverse proxy, adatbázisok) előbb legyen kész, mint az, ami rájuk támaszkodik.

---

## 0. Szolgáltatások áttekintése és csoportosítása

| Szolgáltatás | Cél | Docker? | Megjegyzés |
|---|---|---|---|
| Nginx Proxy Manager *(vagy Traefik)* | Webserver / reverse proxy | ✅ | Egyetlen belépési pont, subdomainek, SSL |
| Portainer | Konténerkezelés (GUI) | ✅ | Már megvan a jelenlegi setupban |
| Webmin | Rendszerfigyelés / adminisztráció | ❌ natív | Rendszerszintű hozzáférés kell neki (hálózat, lemezek, cron) |
| MariaDB | Relációs adatbázis | ✅ | Meglévő appoknak (pl. jelenlegi MariaDB migrálása) |
| PostgreSQL | Relációs adatbázis | ✅ | Fejlesztési projektekhez (sok modern app ezt preferálja) |
| qBittorrent | Torrent letöltő | ✅ | WebUI-n keresztül vezérelve |
| Calibre-Web | Könyvkezelő | ✅ | A Calibre-Library-t olvassa, nem kell hozzá desktop Calibre |
| Immich | Képkezelő és -karbantartó | ✅ | Automatikus rendezés, arcfelismerés, mobil backup |
| Plex | Multimédia szerver | ✅ | GPU passthrough opcionális, de a hardvered (i5-3570T) alapján szoftveres transzkódolás lesz |
| Gitea | Git szerver (fejlesztéshez) | ✅ | A tervezett CI/CD fázisból (2. fázis) áthozva ide, mert a fejlesztői munka korán kelleni fog |
| Docker Registry | Privát image tároló | ✅ | Gitea CI-hoz is kellhet később |

> **Megjegyzés a Webminről:** a Webmin szándékosan natív telepítés, mert rendszerszintű dolgokat kezel (hálózati interfészek, systemd szolgáltatások, cron, lemezkvóták, tűzfal) — ezekhez Dockerben privilegizált, hoszt-szintű hozzáférés kellene, ami gyakorlatilag kiüresítené az izolációs előnyt. Ez architekturálisan helyes döntés, nem kompromisszum.

---

## 1. Fázis — Alap VM provisioning (Terraform)

*Már elkészült váz, ez a végrehajtási lépés.*

- [x] Cloud-init template létrehozása Proxmoxon (Ubuntu Server 22.04/24.04 LTS)
- [ ] Proxmox API token létrehozása Terraformnak (korlátozott jogokkal)
- [ ] `terraform apply` — VM létrehozása
- [ ] Erőforrás-tervezés: mivel minden Dockerben fut egy gépen, javasolt indulásnak **4 vCPU / 6-8 GB RAM**, bővíthetően (a Proxmox host 16 GB RAM-jából reálisan ennyi allokálható a többi VM/LXC mellett)
- [ ] Storage tervezés: **SSD** → OS + adatbázisok + konténer volume-ok (I/O érzékeny); **HDD** → média könyvtár, torrent letöltések, fotók archívuma (nagy méret, kevésbé I/O érzékeny)

---

## 2. Fázis — OS alapkonfiguráció (Ansible)

- [ ] `common` role lefuttatása (megvan a vázban: alap csomagok, időzóna, biztonsági frissítések)
- [ ] `docker` role lefuttatása (Docker Engine + Compose plugin)
- [ ] **Új: `webmin` role** — natív telepítés (apt repo hozzáadása, telepítés, tűzfal port nyitása 10000-en)
- [ ] **Új: `firewall` role** — UFW alapbeállítás (csak a szükséges portok nyitva: 22, 80, 443, 10000)
- [ ] Könyvtárstruktúra létrehozása a hoston a Docker volume-oknak (lásd 3. fázis alatt)
- [ ] Nem-root felhasználó docker csoportba tétele (már megvan a vázban)

---

## 3. Fázis — Hálózat és belépési pont

Ez azért jön ilyen korán, mert **minden további szolgáltatás ezen fog keresztül elérhető lenni** — ha most alakítod ki jól, utána már csak hozzá kell adni az új szolgáltatásokat.

- [ ] **Traefik** telepítése Dockerben — label-alapú service discovery, statikus + dinamikus konfiguráció fájlból
- [ ] **Portainer** telepítése (Dockerben, meglévő stack-ből átemelve vagy újratelepítve)
- [ ] Belső DNS / subdomain stratégia kialakítása (mivel van AdGuard LXC-d, oda helyi DNS rekordok felvehetők, pl. `plex.home.local`, `git.home.local`, `portainer.home.local`)
- [ ] SSL: **egyelőre sima HTTP**, később térünk rá vissza (self-signed vagy Let's Encrypt eldöntendő akkor)

---

## 4. Fázis — Adatbázis réteg

Ez azért előzi meg a fejlesztői és otthoni szolgáltatásokat, mert **több szolgáltatás (Immich, Gitea opcionálisan) rájuk épül**.

- [ ] **MariaDB** konténer — persistent volume-mal, a meglévő adatbázis migrálása erre (jelenleg VM-en fut natívan)
- [ ] **PostgreSQL** konténer — külön projektekhez, illetve mert Immich és néhány modern dev-tool ezt preferálja
- [ ] **phpMyAdmin** áthozása Dockerbe (jelenleg natívan fut) — reverse proxy mögé
- [ ] Backup stratégia kiterjesztése: `mysqldump`/`pg_dump` cron job (illeszkedik a korábban megbeszélt 3-2-1 backup stratégiához)
- [ ] Adatbázis volume-ok SSD-n tárolása (I/O teljesítmény miatt)

---

## 5. Fázis — Otthoni szolgáltatások

- [ ] **qBittorrent** — Dockerben, WebUI reverse proxy mögött, letöltési könyvtár a HDD-n
- [ ] **Calibre-Web** — könyvtár mount-olása, első indításkor library létrehozása/csatolása
- [ ] **Immich** — PostgreSQL-t igényel, ami már megvan a 4. fázisból. Jelenleg havi szintű, manuális telefonos képfeltöltés a use-case, de az Immich nyitva hagyja a lehetőséget a jövőbeli automatikus mobil backupra migráció nélkül
- [ ] **Plex** — média könyvtár mount-olása a HDD-ről; érdemes tudni, hogy az i5-3570T-n **hardveres transzkódolás nincs** (nincs QuickSync ezen a generáción érdemben kihasználható módon Plexhez), szóval direct play-re optimalizált könyvtárstruktúra ajánlott, vagy content előre transzkódolva
- [ ] Meglévő Heimdall dashboard frissítése az új szolgáltatásokkal

---

## 6. Fázis — Fejlesztői szolgáltatások

*Ez korábban a "2. fázis: Gitea + CI/CD" volt a nagy roadmapben — ide hoztuk előre, mert a szerver dev célú használatához hamar kelleni fog.*

- [ ] **Gitea** — Dockerben, MariaDB vagy PostgreSQL backend (érdemes PostgreSQL-t választani, mert Gitea azzal is jól működik és így teszteled mindkét adatbázist éles használatban)
- [ ] **Docker Registry** — privát image tárolásra, később a CI/CD pipeline-hoz kell
- [ ] *(Opcionális)* code-server (VS Code böngészőben) — ha távolról is szeretnél a szerveren fejleszteni

---

## 7. Fázis — Monitoring (a nagy roadmap 1. fázisa, itt illesztve be)

- [ ] Prometheus + Grafana + cAdvisor — most már van mit mérni (sok konténer fut)
- [ ] Grafana dashboard minden szolgáltatáshoz (konténer erőforrás-használat, adatbázis metrikák)

---

## 8. Fázis — Logging, alerting, hardening

- [ ] Loki + Promtail (log aggregáció a Traefikből és a konténerekből)
- [ ] Grafana alerting (pl. lemez betelik, konténer leáll)
- [ ] Fail2ban natív telepítése (Webminhez hasonlóan rendszerszintű, nem Dockerbe való)
- [ ] SSH kulcs-alapú auth kikényszerítése, jelszavas login tiltása

---

## Javasolt könyvtárstruktúra a szerveren (Docker stackekhez)

```
/opt/stacks/
├── proxy/              # Traefik/NPM + docker-compose.yml
├── portainer/
├── databases/
│   ├── mariadb/
│   └── postgresql/
├── media/
│   ├── plex/
│   ├── qbittorrent/
│   └── calibre-web/
├── photos/
│   └── immich/
└── dev/
    ├── gitea/
    └── registry/

/mnt/hdd-storage/
├── media-library/       # Plex által látott könyvtár
├── downloads/           # qBittorrent célkönyvtár
├── books/                # Calibre library
└── photos/               # Immich upload storage

/mnt/ssd-storage/
└── docker-volumes/      # DB-k és egyéb I/O-érzékeny volume-ok
```

Ezt a struktúrát Ansible-lel hozod létre (`file` modul), a docker-compose fájlokat pedig vagy Ansible template-ből generálod, vagy a repódban tárolod és Ansible-lel csak szinkronizálod + `docker compose up -d`-t futtatod rajtuk (`community.docker.docker_compose_v2` modul).

---

## Sorrendi összefoglaló (miért ez a sorrend)

1. **VM létrejön** (Terraform) → enélkül semmi nincs
2. **OS + Docker + Webmin** (Ansible) → alaprendszer, amire minden más épül
3. **Reverse proxy + Portainer** → mert utána minden szolgáltatást ezen keresztül vezetsz be, nem kell utólag átszervezni
4. **Adatbázisok** → mert Immich és Gitea is ezekre támaszkodik
5. **Otthoni szolgáltatások** → ezek egymástól függetlenek, tetszőleges sorrendben jöhetnek, de az adatbázis után, mert Immich-nek kell a Postgres
6. **Fejlesztői szolgáltatások** → Gitea, hogy minél előbb elkezdhesd a saját IaC repódat is oda push-olni gyakorlásképp
7. **Monitoring, majd Logging/Hardening** → ez a meglévő nagy roadmap sorrendje, változatlanul, mert értelemszerűen a legvégén van értelme mérni/monitorozni, amikor már sok minden fut

---

## Nyitott kérdések, amiket érdemes eldönteni implementáció előtt

- ~~Traefik vagy Nginx Proxy Manager?~~ → **eldőlt: Traefik** (illeszkedik a nagy roadmap 4. fázisához, label-alapú auto-discovery, IaC-barát konfiguráció)
- ~~Immich vagy PhotoPrism a fotókezeléshez?~~ → **eldőlt: Immich** (nyitva hagyja a jövőbeli automatikus mobil backup lehetőségét)
- ~~SSL: Let's Encrypt vagy self-signed?~~ → **eldőlt: egyelőre sima HTTP**, SSL-t külön lépésben oldjuk meg később
- A jelenlegi natív MariaDB adatait hogyan migráljuk a Docker verzióba — **elhalasztva**, később külön lépésként oldjuk meg (dump + restore terv, illeszkedik a meglévő 3-2-1 backup-stratégiához)
