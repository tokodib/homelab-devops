# Architektúra döntések

## Miért Terraform + Ansible, és nem csak az egyik?

- **Terraform** deklaratív, állapot-alapú (state file), és arra való, hogy erőforrásokat (VM, hálózat, storage) hozzon létre/módosítson/töröljön idempotens módon. Kiváló a "mi legyen ott" kérdésre.
- **Ansible** procedurális/deklaratív hibrid, agentless (SSH-n keresztül dolgozik), és arra való, hogy egy már létező gépen belül konfiguráljon dolgokat. Kiváló a "mi legyen a gépen belül" kérdésre.

A kettő kombinálása az iparban is elterjedt minta (pl. Terraform hozza létre az AWS EC2-t, Ansible telepíti rá az appot).

## Proxmox provider választás: `bpg/proxmox` vs `Telmate/proxmox`

A `bpg/proxmox` provider aktívabban karbantartott, jobban támogatja az újabb Proxmox API funkciókat (pl. cloud-init, agent-alapú IP lekérdezés), ezért ezt választottuk a vázban.

## Miért statikus Ansible inventory kezdésnek?

Egyetlen VM esetén a statikus inventory egyszerűbb és átláthatóbb. Ha több VM/node kezelése válik szükségessé, érdemes áttérni a dinamikus Proxmox inventory plugin-ra, ami automatikusan lekérdezi a futó VM-eket a Proxmox API-n keresztül.

## State fájl kezelése

Kezdésnek a lokális Terraform state elegendő egy egyszemélyes homelab projektnél. Amint több gépről/csapatban dolgoznál rajta, egy remote backend (S3-kompatibilis tárhely, pl. self-hosted MinIO) szükségessé válik a lock-olás és a konzisztencia miatt.
