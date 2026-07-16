# LEMP Stack Research Review

> **แอปเป้าหมาย:** LEMP Stack Dev Base Image
> **ขอบเขต:** Hardened Image สำหรับนักพัฒนาซอฟต์แวร์ (Linux + Nginx + PHP-FPM + MariaDB) บูต VM แล้วรันระบบเว็บและฐานข้อมูลในตัวพร้อมใช้งานทันที

---

## 1. Upstream & Docker Image Selection

| Component | Target Image | Tag / Version | Digest / Hash | Size | Role |
|---|---|---|---|---|---|
| Web App / Proxy | `library/nginx` | `1.30.3` (stable) | `sha256:5825bde471b8` | ~63MB | Web Server (HTTP/HTTPS) |
| PHP Engine | `library/php` | `8.3-fpm` (8.3.31) | `sha256:efaea017a0c2` | ~172MB | PHP-FPM Processing Service |
| Database | `library/mariadb` | `11.4.12` (LTS) | `sha256:a794d9eb009e` | ~105MB | Relational Database |

---

## 2. Technical Diagrams

### 2.1 User Journey Diagram (การใช้งานของลูกค้า)
แผนภาพลำดับการทำงานและเข้าใช้งาน LEMP stack หลังจากผู้ใช้งานสั่งรัน VM

```mermaid
sequenceDiagram
    autonumber
    actor Developer as 👤 นักพัฒนา / ผู้ใช้
    participant VM as 🖥️ VM Host (OpenStack)
    participant Boot as ⚙️ Oneshot Bootstrap Service
    participant Web as 🌐 Browser (Web UI)

    Developer->>VM: สั่ง Launch VM Instance (ครั้งแรก)
    VM->>Boot: สตาร์ท lemp-bootstrap.service
    Boot->>Boot: สร้างรหัสผ่านสุ่มสำหรับ MariaDB Root/User
    Boot->>Boot: สร้าง /opt/lemp/.env และเขียน credentials
    Boot->>Boot: สั่งรัน docker compose up -d (เริ่ม nginx, php-fpm, db)
    Boot->>Boot: ตรวจสอบความพร้อมของ PHP-FPM และจบกระบวนการ
    Developer->>VM: SSH เข้า VM เพื่อดู credentials และจัดการโค้ด
    VM-->>Developer: แสดง MOTD บอกข้อมูลระบบและคำสั่งช่วยเหลือ (lemp-*)
    Developer->>Web: เปิดเว็บ http://<VM-IP>/ เพื่อทดสอบ PHP
    Web-->>Developer: แสดงหน้าข้อมูล Nginx Default หรือ PHP Index
    Developer->>VM: นำไฟล์ PHP เข้าวางที่ /var/www/html เพื่อเริ่มทำงาน
```

---

### 2.2 System Architecture Diagram
แสดงโครงสร้าง Container, Docker Networks, Volumes และการเชื่อมต่อภายใน VM

```mermaid
graph TD
    subgraph VM ["🖥️ OpenStack VM (Ubuntu 26.04)"]
        subgraph Ports ["🔓 Exposed Ports"]
            P80["Port 80 (HTTP)"]
            P443["Port 443 (HTTPS - Optional)"]
            P22["Port 22 (SSH)"]
        end

        subgraph DockerNet ["🔒 Internal Docker Network (lemp-net)"]
            Proxy["🌐 Nginx Container"]
            App["📦 PHP-FPM Container (Port 9000)"]
            DB["🗄️ MariaDB Container (Port 3306)"]
        end

        subgraph Mounts ["💾 Persistent Storage Volumes"]
            VolWeb["www_data (/var/www/html)"]
            VolDB["db_data (/var/lib/mysql)"]
            VolNginxConf["./config/nginx/default.conf (/etc/nginx/conf.d/)"]
            VolPHPConf["./config/php/php.ini (/usr/local/etc/php/conf.d/)"]
        end
    end

    %% External Connections
    Developer["👤 Developer"] -->|SSH| P22
    Developer -->|HTTP/HTTPS Request| P80 & P443

    %% Routing
    P80 & P443 --> Proxy
    Proxy -->|Mount Web Files| VolWeb
    App -->|Mount Web Files| VolWeb
    Proxy -->|FastCGI to php-fpm:9000| App
    App -->|TCP Connection to DB| DB

    %% Config Mounts
    Proxy -.->|Mount| VolNginxConf
    App -.->|Mount| VolPHPConf
    DB -.->|Mount| VolDB
```

---

### 2.3 Bootstrap Execution Flow
แผนภาพแสดงการทำงานในระดับสคริปต์เมื่อมี VM บูตครั้งแรก เพื่อควบคุมความเป็น Idempotency

```mermaid
graph TD
    Start["🚀 First Boot / Systemd Start"] --> CheckEnv{"🔒 มีไฟล์ /opt/lemp/.env หรือไม่?"}
    
    CheckEnv -->|มี - บูตครั้งถัดๆ ไป| StartCompose["🐳 docker compose --profile http up -d"]
    StartCompose --> Exit["✅ เสร็จสิ้นการบูต (Exit 0)"]
    
    CheckEnv -->|ไม่มี - บูตครั้งแรก| GenSecrets["🔑 สุ่มรหัสผ่าน MariaDB Root/User (Alphanumeric Only)"]
    GenSecrets --> CreateEnv["📝 สร้าง /opt/lemp/.env"]
    CreateEnv --> SaveCreds["💾 บันทึกรหัสผ่านไว้ที่ /root/lemp-credentials.txt"]
    SaveCreds --> StartComposeHTTP["🐳 docker compose --profile http up -d"]
    StartComposeHTTP --> WaitFPM["⏳ รอและทดสอบสถานะ PHP-FPM container"]
    WaitFPM --> Exit
```

---

### 2.4 Port & Security Diagram (Security Boundaries)
แสดงการกักกันและสิทธิ์การเข้าถึงพอร์ตต่างๆ ของแต่ละ component

```mermaid
graph TD
    subgraph VM_Boundary ["🖥️ VM Host Security Boundary"]
        subgraph Firewall ["🛡️ VM UFW Firewall"]
            SSH["Port 22: SSH (Allow)"]
            HTTP["Port 80: HTTP (Allow)"]
            HTTPS["Port 443: HTTPS (Allow - Optional)"]
            DB_Port["Port 3306 (Block External)"]
        end

        subgraph Docker_Bridge_Network ["🔒 Isolated Docker Network Only"]
            NginxProxy["Proxy Port 80 / 443"]
            FPM_Port["PHP-FPM Port 9000 (Internal Only)"]
            MariaDB_Port["MariaDB Port 3306 (Internal Only)"]
        end
    end

    Internet["🌐 External Internet"] ---> SSH & HTTP & HTTPS
    Internet -.-x|Blocked| DB_Port

    HTTP & HTTPS ---> NginxProxy
    NginxProxy --->|Internal Network| FPM_Port
    FPM_Port --->|Internal Network| MariaDB_Port
```

---

## 3. Design Decisions & Rationale

| Topic | Decision | Rationale | Alternatives Considered |
|---|---|---|---|
| **PHP Runtime** | `php:8.3-fpm` (Debian-based) | รองรับความเข้ากันได้ของปลั๊กอินและโมดูลสำหรับ PHP ยอดนิยม (WordPress, Laravel) ได้กว้างขวางที่สุด และมี tools ปรับแต่งง่าย | `php:8.3-fpm-alpine` — ขนาดเล็กแต่เสี่ยงกับการติดตั้ง PHP extensions บางตัว เช่น GD, zip, intl |
| **Shared Volume** | ใช้ Named Volume `www_data` สำหรับ `/var/www/html` | การที่ Nginx และ PHP-FPM ใช้ volume ร่วมกัน ณ พาธเดียวกัน ช่วยแก้ปัญหา "Primary script unknown" และเรื่องสิทธิ์การอ่านเขียนไฟล์ | ใช้ host bind mount — มักเกิดปัญหา permission mismatch ของ UID/GID ระหว่างโฮสต์และ container |
| **Image Freeze** | Pre-build local images ใน VM ระหว่างการสร้าง Golden Image | เพื่อการทำ Offline-safety บูตครั้งแรกจะไม่มีคำสั่ง `docker compose pull` ทำให้การสร้าง VM ใช้งานได้ทันทีแม้ไม่มีเน็ตภายนอก | โหลด container ออนไลน์ตอนบูตครั้งแรก — หากวันใด Docker Hub มีปัญหา VM จะสตาร์ทไม่ขึ้นทันที |
| **Helper Aliases** | มีคำสั่งช่วยจัดการ `lemp-*` บน Host OS | อำนวยความสะดวกให้นักพัฒนาสามารถดูสถานะ ดูล็อก หรือ SSH เข้าไปทดสอบใน container ได้ผ่านคำสั่งสั้นๆ เช่น `lemp-status` | รัน docker compose ยาวๆ — ยุ่งยากสำหรับผู้ใช้ที่ต้องการความเร็ว |

---

## 4. Community Signals & Known Issues

| Issue / Gotcha | Severity | Mitigation / Workaround | Source |
|---|---|---|---|
| **Primary script unknown** | Must | กำหนด `fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;` ใน Nginx และ Mount directory `/var/www/html` ให้ตรงกันทั้งสองฝั่ง | StackOverflow (149 votes) |
| **Database starts after PHP** | Must | ใช้ Docker compose healthcheck บน MariaDB และระบุ `depends_on` แบบ `service_healthy` บนฝั่ง PHP-FPM เพื่อรอฐานข้อมูลพร้อมจริง | StackOverflow |
| **Information Disclosure** | Should | กำหนด `server_tokens off;` ใน Nginx และ `expose_php = Off` ใน php.ini เพื่อปิดการแสดงผลเวอร์ชันใน headers | Security best practices |

---

## 5. User Needs

### 5.1 Beginner (นักพัฒนาเว็บไซต์มือใหม่)
*   **เปิดใช้งานเร็ว:** บูตระบบแล้วสามารถทดสอบรันไฟล์ `.php` และเข้าหน้าเว็บทดสอบได้ทันที
*   **คำอธิบายชัดเจน:** มี MOTD บอกพอร์ต ข้อมูลการเข้าใช้ และ credentials ฐานข้อมูล

### 5.2 Intermediate (ผู้ดูแลระบบเว็บและ IT Ops)
*   **ปรับแต่งค่า PHP:** แก้ไขไฟล์ `/opt/lemp/config/php/php.ini` เพื่อปรับ `memory_limit` หรือ `upload_max_filesize` ได้สะดวก
*   **ความสะดวกของสคริปต์:** มีคำสั่งอำนวยความสะดวกเช่น `lemp-shell` และ `lemp-db` ช่วยทดสอบรันคำสั่งโดยตรง

### 5.3 Advanced (ผู้ดูแลระบบเซิร์ฟเวอร์สเกลใหญ่)
*   **ความปลอดภัยฐานข้อมูล:** พอร์ต MariaDB และ PHP-FPM ถูกจำกัดไว้ภายใน Docker Network เท่านั้น ไม่เปิดสาธารณะภายนอก
*   **SSL Support:** มี Nginx config template สำหรับเปิดใช้งาน HTTPS หลังติดตั้ง cert จริงเรียบร้อยแล้ว

---

## 6. Verification & Acceptance Criteria

### 6.1 Unit Verification (ฝั่ง VM)
- [ ] ตรวจสอบว่าไม่มีไฟล์ `/opt/lemp/.env` หรือ credentials ดั้งเดิมหลงเหลืออยู่ใน Golden Image
- [ ] systemd service `lemp-bootstrap.service` อยู่ในสถานะ enabled
- [ ] container images ท้องถิ่นถูกสร้างและตรวจเจอเรียบร้อย เช่น `lemp-local-php:8.3-fpm-tools`

### 6.2 Browser Acceptance (E2E)
- [ ] เมื่อบูต VM ใหม่ สามารถดึงข้อมูลหน้าเว็บ HTTP พอร์ต 80 ได้ผลลัพธ์ปกติ (HTTP 200)
- [ ] สามารถเชื่อมต่อและดึงข้อมูลจาก MariaDB ผ่าน PHP script ภายใน container ได้สำเร็จ
