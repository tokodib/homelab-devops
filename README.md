# Homelab DevOps – IaC váz (Terraform + Ansible)

Ez a repó a Proxmox homelab szerver Infrastructure as Code alapú kiépítését dokumentálja.

**Cél:** egy Ubuntu Server VM automatizált létrehozása Terraformmal, majd konfigurálása Ansible-lel — a teljes folyamat kódból, verziózva, reprodukálhatóan.

## Architektúra

```
Laptop (ez a repo)
   │
   ├── terraform/   → VM létrehozása a Proxmoxon (provisioning)
   │                   klónozás cloud-init template-ből
   │
   └── ansible/     → a létrejött VM konfigurálása (configuration management)
                        alap csomagok, Docker telepítése, stb.
```

**Munkafolyamat:** `terraform apply` → VM létrejön és IP-t kap → az IP bekerül az Ansible inventory-ba → `ansible-playbook` lefuttatja a konfigurációt.

## Előfeltételek

1. **Proxmox oldalon:**
   - Egy cloud-init kompatibilis Ubuntu/Debian template VM (lásd: [Proxmox cloud-init template készítés](https://pve.proxmox.com/wiki/Cloud-Init_Support))
   - Egy dedikált API user + token Terraformnak, korlátozott (nem root) jogokkal
2. **Laptopon (lokálisan):**
   - [Terraform](https://developer.hashicorp.com/terraform/install) (>= 1.6)
   - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
   - SSH kulcspár (`ssh-keygen -t ed25519`)

## Használat

### 1. Terraform – VM létrehozása

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# szerkeszd ki a terraform.tfvars-t a saját Proxmox adataiddal

terraform init
terraform plan
terraform apply
```

Az `apply` végén a `vm_ip` output megadja az új VM IP címét.

### 2. Ansible – VM konfigurálása

```bash
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml
# írd be a Terraformból kapott IP-t

ansible-playbook playbooks/site.yml
```

## Titkok kezelése

- A `terraform.tfvars` és a `hosts.yml` **nincsenek** verziózva (lásd `.gitignore`) — csak a `.example` sablonok kerülnek fel GitHubra.
- A Terraform state (`terraform.tfstate`) érzékeny adatot tartalmazhat, szintén ki van zárva. Kezdésnek lokális state oké; később remote backend (pl. S3-kompatibilis MinIO a homelabban) átgondolandó.
- Ha Ansible-ben jelszavakat/titkokat kell kezelni, `ansible-vault` használata javasolt (még nincs bekötve ebben a vázban).

## Roadmap / következő lépések

- [ ] `ansible-vault` bevezetése titkokhoz
- [ ] Dinamikus Proxmox inventory plugin Ansible-hez (statikus helyett)
- [ ] Remote Terraform state backend
- [ ] Monitoring role (node_exporter) hozzáadása a szerverhez
- [ ] CI pipeline (Gitea Actions) `terraform plan` automatikus futtatásához PR-eken

## Struktúra

```
homelab-devops/
├── README.md
├── JOURNAL.md               # dátumozott naplóbejegyzések a fejlődésről és döntésekről
├── .gitignore
├── terraform/
│   ├── versions.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.yml.example
│   ├── playbooks/
│   │   └── site.yml
│   └── roles/
│       ├── common/tasks/main.yml
│       └── docker/tasks/main.yml
└── docs/
    ├── architecture.md      # architektúra döntések indoklása
    └── roadmap.md           # teljes szolgáltatás- és fázis-roadmap
```

## Naplózás

A `JOURNAL.md` fájl dátumozott bejegyzésekben követi a projekt fejlődését — mit csináltunk, milyen döntést miért hoztunk, mibe futottunk bele. Egy napló bejegyzés és a hozzá tartozó kód/config változás együtt kerül egy commitba, hogy a git history és a napló szinkronban maradjon.
