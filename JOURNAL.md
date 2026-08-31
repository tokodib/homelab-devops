# Napló

Ez a fájl a homelab-devops projekt fejlődését dokumentálja időrendben — mit csináltam, milyen döntéseket hoztam és miért, mit tapasztaltam, mi ment el rosszul.

**Cél:** ha valami elromlik, vagy fél év múlva vissza kell nézni "miért is csináltam ezt így", legyen egy olvasható, kronologikus feljegyzés a kód mellett — ne csak a git log üres commit üzenetei maradjanak meg.

## Formátum

Minden bejegyzés egy `##` dátumozott szekció. Egy bejegyzésen belül érdemes rögzíteni:
- **Mit csináltam** — röviden, ténymegállapítás szinten
- **Miért így** — ha volt döntési pont (pl. Traefik vs NPM), itt a rövid indoklás, vagy hivatkozás a `docs/architecture.md`-re
- **Amit tapasztaltam / hiba, amibe belefutottam** — ez a legértékesebb rész később
- **Következő lépés** — mi jön ezután

Egy napló bejegyzés és a hozzá tartozó kód/konfiguráció változás **együtt kerüljön be egy commitba**, hogy a git history és a napló szinkronban maradjon.

---

## 2026-08-29 — Projekt indítása, roadmap és váz összeállítása

**Mit csináltam:**
- Összeraktam a Terraform + Ansible alapvázat (`terraform/`, `ansible/` könyvtárak) a Proxmoxon futó Ubuntu Server VM automatizált létrehozásához és konfigurálásához
- Elkészült a teljes szolgáltatás-roadmap (`docs/` és a repo gyökerében várható roadmap dokumentum): webserver, adatbázisok (MariaDB + PostgreSQL), torrent kliens, Calibre-Web, Webmin, Portainer, Immich, Plex, Gitea

**Döntések:**
- **Webmin natívan** telepítve marad, nem Dockerben — rendszerszintű hozzáférést igényel (hálózat, cron, tűzfal), amit Dockerben csak a konténer-izoláció kiüresítésével lehetne megoldani
- **Traefik** a reverse proxy Nginx Proxy Manager helyett — label-alapú automatikus service discovery, fájlban/kódban élő konfiguráció (Git-barát, NPM adatbázis-alapú konfigja nem az), és amúgy is szerepelt a nagyobb DevOps roadmap egy későbbi fázisában, így nem kell később migrálni
- SSL egyelőre **elmarad** — sima HTTP-vel indulunk, ezt külön lépésben oldjuk meg, miután a Traefik alapok stabilan futnak
- **Immich** a képkezeléshez PhotoPrism helyett — bár a jelenlegi use-case (havi szintű, manuális telefonos képfeltöltés) nem használja ki az Immich fő erősségét (megbízható automatikus mobil háttér-backup), a döntés azért esett rá, hogy nyitva maradjon a lehetőség a jövőbeli automatikus mentésre migráció nélkül
- A meglévő natív **MariaDB adatok Docker-be migrálása elhalasztva** — külön lépésként kezeljük majd, nem blokkolja a jelenlegi tervezést

**Következő lépés:** Proxmox cloud-init template létrehozása, hogy a Terraform váz ténylegesen tudjon belőle VM-et klónozni.

---
### 2026-08-29 - Proxmox Ubuntu cloud template létrehozása
- Proxmoxba ssh keresztül bejelentkezni 
-  `wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img`
-  `sudo qm create 9000 --name ubuntu-cloud-template --memory 4096 --cores 2 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci` (muszáj `sudo` mert sima felhasználó ként vagyok bejelentkezve - 9000 ID jelöli a templatekat)
-  `sudo qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm` - Image importálása lemezzé
-  `sudo qm set 9000 --scsi0 local-lvm:vm-9000-disk-0` - Lemez felcsatolása a VM-hez
-  `sudo qm resize 9000 scsi0 +25G` - A partíció megnövelése, hogy elférjenek rajta a dolgok.
-  `sudo qm set 9000 --ide2 local-lvm:cloudinit` - egy cdrom hozzáadása
-  `sudo qm set 9000 --boot order=scsi0` - A bootsorrend meghatározása
-  `sudo qm set 9000 --serial0 socket --vga serial0` - cloud imageknak gyakran nincs grafikus boot kimenete ezért kell soros kimenet, hogy ne vakon dolgozzunk
-  `sudo qm set 9000 --agent enabled=1` az qemu agent bekapcsolása
-  `sudo qm template 9000` - a VM templétté alakítása, innen már nem indítható, csak klónozható.
-  SSH-KEY átadása a templatenak : 
-  laptopon : `cat ~/.ssh/id_ed25519.pub` kimásolni az ssh kulcsot majd a pm serveren `nano ~/laptop_key.pub` belemásolni, `sudo qm set 9000 --sshkey laptop_key.pub`
**Döntések:** Egyenlőre nem hozok létre ansible control node-ot a PM gépen, szűkös erőforrások miatt, a laptopot fogom ACN-nek használni.

### 2026-08-29 - A Template klónozása, indítása
-   `sudo qm config 9000` - egy utolsó ellenőrzés
-   `sudo qm clone 9000 222 --name axion17 --full` - Template klónozása - 222 megjegyezhető, axion a serverek neve, 17 meg a szerencseszámom :)
-   `sudo qm set 222 --ipconfig0 ip=192.168.1.222/24,gw=192.168.1.1` - az IP cím statikus legyen a bejelentkezések miatt.
-   `sudo qm start 222` - indítás
-   kilépés a ProxMox ssh-ból
-   `ssh ubuntu@192.168.1.222` Laptopról lépünk be az új ubuntu cloud gépünkre.

### 2026-08-29 - Terraformmal készítsük az új szervert
- `sudo visudo -f /etc/sudoers.d/terraform` 
- a végére hozzáadni: `balazs ALL=(root) NOPASSWD: /usr/sbin/pvesm
balazs ALL=(root) NOPASSWD: /usr/sbin/qm
balazs ALL=(root) NOPASSWD: /usr/bin/tee /var/lib/vz/snippets/[a-zA-Z0-9_][a-zA-Z0-9_.-]*`
- Terraform telepítése Linux mintre: `echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com noble main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform`
- Proxmox WebUI-n beállítani a terraform API-t:

1
Dedikált szerepkör (role) létrehozása
Proxmox web UI-ban: Datacenter → Permissions → Roles → Create. Nevét add meg pl. 'Terraform'. A Privileges listából pipáld ki legalább ezeket: VM.Allocate, VM.Clone, VM.Config.CDROM, VM.Config.Cloudinit, VM.Config.CPU, VM.Config.Disk, VM.Config.HWType, VM.Config.Memory, VM.Config.Network, VM.Config.Options, VM.Audit, VM.Monitor, VM.PowerMgmt, VM.Migrate, Datastore.Allocate, Datastore.AllocateSpace, Datastore.AllocateTemplate, Datastore.Audit, Pool.Allocate, Sys.Audit, Sys.Console, Sys.Modify, SDN.Use, User.Modify. Ez mindent enged, amire a VM klónozáshoz/kezeléshez szükség van, de nem ad teljes admin jogot.

2
Dedikált Proxmox user létrehozása
Datacenter → Permissions → Users → Add. User name: pl. 'terraform', Realm: 'Proxmox VE authentication server' (pve), adj neki jelszót (ezt utána már nem is fogod használni, mert a token független lesz tőle). Így lesz belőle 'terraform@pve'. Ez elkülöníti a Terraform hozzáférését a te személyes user-edtől.

3
A szerepkör hozzárendelése a userhez
Datacenter → Permissions → Add → User Permission. Path: '/' (vagy szűkítheted egy konkrét poolra/node-ra később). User: terraform@pve. Role: Terraform (amit az 1. lépésben csináltál). 'Propagate' maradjon bepipálva, hogy öröklődjön az alá tartozó objektumokra is.

4
API Token generálása a userhez
Datacenter → Permissions → API Tokens → Add. User: terraform@pve. Token ID: pl. 'tf-token'. FONTOS: a 'Privilege Separation' checkbox-ot vedd ki (uncheck), így a token örökli a user teljes jogosultságát (amit a 3. lépésben beállítottál). Ha bepipálva hagyod, a tokennek külön is meg kellene adnod a jogokat.

5
A Secret elmentése — EZ CSAK EGYSZER JELENIK MEG
Létrehozás után a Proxmox mutat egy Token ID-t (pl. 'terraform@pve!tf-token') és egy Secret-et (egy UUID-szerű string). Másold ki AZONNAL és mentsd el biztonságosan — ha bezárod az ablakot, többé nem láthatod, újra kellene generálni. Ezt a két értéket egyben, '=' jellel összefűzve használja majd a Terraform tfvars fájl.

6
Token tesztelése curl-lel
A laptopodon (nem a Proxmoxon) futtasd: curl -k -H "Authorization: PVEAPIToken=terraform@pve!tf-token=<ide-a-secret>" https://<proxmox-ip>:8006/api2/json/nodes — ha JSON válaszban látod a node adatait, a token működik és jó a jogosultság.

**HIBA:** Mivel ZSH-t használok így '' kellett használni a "" helyett, előtte meg egy `set +H` parancsot.

**ÉSZREVÉTEL:** Az ubuntu cloud template-ba be kell integrálni a qemu-guest-agent-ot mert sokáig elhúzódik a terraform clónozása, nem kap vissza infót, hogy készen van a VM. 

**MEGOLDÁS:** Clónozni a 9000 --> 9001-re, telepíteni a qemu guest agent-ot, kikapcsolás előtt törölni mindent `sudo cloud-init clean`, majd a 9001-et lezárni templatnek, majd azt visszaklónozni 9000-re és azt lezárni templatenak. Hasznos operáció `sudo cloud-init clean`. Újraterraformálni

### 2026-08-30 - Kézzel írt HCL 
- A Claude AI által írt kódot leegyeszerűsítve átírtam az érthetőség kedvéért.
- `terraform init` - inicializálás, letölti a szükséges providerokat
- `terraform plan` - elkészíti a tervet, szól a hibákért
- `terraform apply` - megvalósítsa a tervet. Az axion17 VM elkészült: 
  **proxmox_virtual_environment_vm.axion17: Creation complete after 1m21s [id=222]**
- `terraform destroy` - ha törölni akarjuk a VM-et
- `ssh ansible@192.168.1.222` címmel bejelentkezhetünk a VM-be

### 2026-08-30 - Ansible
- Könyvtárstruktúra és az `inventory.ini` fájl létrehozása, majd `ansible.cfg`
- `ansible devops_lab -m ping` - ping: pong válasz volt, teszteltük a kapcsolatot az ansible és a VM között
- `homelab-devops/ansible/roles/common/tasks/main.yml` könyvtár és fájl létrehozása

### 2026-08-31 - Ansible bővitgetések
- `tasks/main.yml` és `site.yml` fájlok bővitgetése és `ansible-playbook site.yml` futtatása. Az ufw konfigurálása után `ssh`-t ellenőrizni kell, hogy nem zártuk-e ki magunkat a szerverről.
- **Fontos:** a `ufw enable` sorrendje kritikus — előbb mindig az `allow 22/tcp` szabályt kell felvenni, utána jöhet a `state: enabled` + `policy: deny`. Ha fordítva, SSH-n keresztül kizárhatjuk magunkat.
### 2026-08-31 - Ansible: docker role
- GPG kulcs + hivatalos Docker apt repo hozzáadása (`{{ ansible_distribution_release }}` dinamikus fact, nem hardcode-olt `noble` — axion17 tiszta Ubuntu 24.04, nem Mint, szóval itt nem probléma).
- Docker CE + cli + containerd + buildx + compose plugin telepítve.
- Fontos: az `ansible` user docker csoportba adása csak ÚJ SSH session-ben lép érvénybe, a meglévő nem frissül automatikusan.
- Fontos: `append: yes` a `user` modulnál, különben lecseréli a user összes csoportját ahelyett, hogy hozzáadná az újat.
- Deprecation warningok (`apt_repository`, `ansible_*` factek) egyelőre tudatosan figyelmen kívül hagyva, technikai adósságként jegyezve.
<!-- Új bejegyzések ide, a lista tetejére vagy aljára — legyél konzisztens, javasolt: időrendben lefelé, mint most -->
