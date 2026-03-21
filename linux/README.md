# Đồ Án Linux — DevOps Class

## Bối cảnh

Bạn là DevOps engineer duy nhất của một startup. Công ty chưa có gì — bạn phải xây toàn bộ hạ tầng IT nội bộ từ đầu.

---

## Kiến trúc Hạ tầng — Infrastructure Architecture

Hệ thống gồm 4 VM kết nối trong mạng nội bộ `corp.internal`. `infra-vm` đóng vai trò trung tâm — cung cấp DNS và NTP cho toàn bộ hệ thống. `storage-vm` chạy MinIO lưu object. `app-vm` chạy toàn bộ tầng ứng dụng và database. `client-vm` dùng để kiểm tra và test.

```
                          mạng corp.internal
  ┌───────────────────────────────────────────────────────────────────┐
  │                                                                   │
  │  ┌─────────────────┐      ┌─────────────────┐                     │
  │  │    infra-vm     │      │   storage-vm    │                     │
  │  │─────────────────│      │─────────────────│                     │
  │  │ DNS  (bind9)    │      │ data partition  │                     │
  │  │ NTP  (chrony)   │      │ MinIO           │                     │
  │  │                 │      │ (single drive)  │                     │
  │  └─────────────────┘      └────────┬────────┘                     │
  │          │                         │                              │
  │          │                         ▼                              │
  │          │               ┌─────────────────┐                      │
  │          └──────────────▶│    app-vm       │                      │
  │                          │─────────────────│                      │
  │                          │ Nginx + TLS     │                      │
  │                          │ Ping App (x1)   │                      │
  │                          │ MariaDB         │                      │ 
  │                          │ MongoDB         │                      │ 
  │                          │ Redis           │                      │
  │                          └────────▲────────┘                      │
  │                                   │ HTTPS (app.corp.internal)     │
  │                          ┌────────┴────────┐                      │
  │                          │   client-vm     │                      │
  │                          │─────────────────│                      │
  │                          │ kiểm tra & test │                      │
  │                          └─────────────────┘                      │
  │                                                                   │
  └───────────────────────────────────────────────────────────────────┘
```

### Nâng cao (điểm cộng)

Phần nâng cao yêu cầu cấu hình **High Availability** cho từng thành phần — hệ thống phải tiếp tục hoạt động khi một node bị tắt. Học viên chọn làm một hoặc nhiều hạng mục, mỗi hạng mục tính điểm riêng.

| Thành phần | Cơ bản | Nâng cao |
|---|---|---|
| MinIO | 1 drive | 1 host, 4 drives — erasure coding (chịu được 1–2 disk chết) |
| MariaDB | single instance | primary + replica |
| MongoDB | single instance | replica set 3 node (community edition) |
| Ping App | 1 instance | 2 instances, Nginx load balance |

---

## Kiến trúc Ứng dụng — Application Architecture

```
  Browser / client-vm
        │
        │ HTTPS  app.corp.internal
        ▼
  ┌─────────────────────────────────────────────┐
  │          Nginx (TLS termination)            │
  │          reverse proxy / load balancer      │
  └──────────────────────┬──────────────────────┘
                         │ HTTP (nội bộ)
                         ▼
  ┌─────────────────────────────────────────────┐
  │               Ping App                      │
  │         (do giảng viên cung cấp)            │
  │                                             │
  │   kiểm tra kết nối tới từng service         │
  │   hiển thị trạng thái ✅ / ❌               │
  └──────┬──────────────┬──────────────┬────────┘
         │              │              │
         ▼              ▼              ▼
   ┌──────────┐  ┌──────────┐  ┌──────────┐
   │ MariaDB  │  │ MongoDB  │  │  Redis   │
   │  SELECT 1│  │   ping   │  │   PING   │
   └──────────┘  └──────────┘  └──────────┘

         │  bucket exists?
         ▼
   ┌──────────────────┐
   │      MinIO       │
   │  (object store)  │
   └──────────────────┘
```

---

## Yêu cầu Tài nguyên — Resource Requirements

Chọn **một** trong hai lựa chọn bên dưới.

> **Khuyến nghị:** Làm trên VirtualBox trước để làm quen với cấu hình — nhanh hơn, không tốn chi phí. Sau khi thành thạo mới chuyển sang AWS để trải nghiệm môi trường cloud thực tế.

### Lựa chọn A — VirtualBox (máy tính cá nhân)

#### Cơ bản

| VM | Vai trò | vCPU | RAM | Disk |
|---|---|---|---|---|
| `infra-vm` | DNS + NTP | 1 core | 1 GB | 10 GB |
| `storage-vm` | MinIO | 1 core | 2 GB | 10 GB |
| `app-vm` | Nginx + DB + App | 2 core | 3 GB | 10 GB |
| `client-vm` | Kiểm tra | 1 core | 1 GB | 8 GB |
| **Máy host (cần trống)** | |  | **9 GB** | **40 GB** |

#### Advanced (optional)

| VM thêm | Vai trò | vCPU | RAM | Disk |
|---|---|---|---|---|
| `storage-vm` *(thay thế)* | MinIO 4-drive erasure coding | 1 core | 2 GB | 4 × 8 GB |
| `app-vm-2` | Ping App replica thứ 2 | 2 core | 2 GB | 10 GB |
| `mongo-vm-2`, `mongo-vm-3` | MongoDB replica set | 1 core mỗi VM | 1 GB mỗi VM | 8 GB mỗi VM |
| `mariadb-replica` | MariaDB replica | 1 core | 1 GB | 8 GB |
| **Máy host (cần trống)** | |  | **18 GB** | **100 GB** |

> Cơ bản: máy 16 GB RAM là đủ. Nâng cao: khuyến nghị 32 GB RAM.

### Lựa chọn B — AWS EC2

> **Lưu ý đặt tên:** Tất cả EC2 instance phải đặt **Name tag** theo format `2601-<student-id>-<role>`, ví dụ: `2601-DE012-infra`, `2601-DE012-app`.

#### Cơ bản

| Instance | Loại | vCPU / RAM | EBS | Chi phí / toàn dự án* |
|---|---|---|---|---|
| `infra` | t3.micro | 2 / 1 GB | 10 GB | ~$0.5 |
| `storage` | t3.micro | 2 / 1 GB | 10 GB | ~$0.5 |
| `app` | t3.small | 2 / 2 GB | 10 GB | ~$1 |
| `client` | t3.micro | 2 / 1 GB | 8 GB | ~$0.5 |
| **Tổng mỗi học viên** | | | | **~$2–4** |

#### Advanced (optional)

| Instance thêm | Loại | vCPU / RAM | EBS | Chi phí / toàn dự án* |
|---|---|---|---|---|
| `storage` *(thay thế)* | t3.small | 2 / 2 GB | 4 × 8 GB | ~$1–2 |
| `app-2` | t3.small | 2 / 2 GB | 10 GB | ~$1 |
| `mongo-2`, `mongo-3` | t3.micro mỗi VM | 2 / 1 GB | 8 GB mỗi VM | ~$0.5 mỗi VM |
| `mariadb-replica` | t3.micro | 2 / 1 GB | 8 GB | ~$0.5 |
| **Tổng mỗi học viên** | | | | **~$6–10** |

> ⚠️ **Tắt instance khi không làm việc** — nếu để chạy 24/7 cả tuần chi phí có thể tăng gấp 3–4 lần.
> Tất cả dùng Ubuntu 22.04 LTS, cùng region, cùng VPC.

---

## Phases

### Phase 1 — OS & Disk Setup

Cài OS và cấu hình disk cho tất cả VM theo đúng bảng tài nguyên ở trên.

1. Cài Ubuntu 22.04 LTS (VirtualBox hoặc EC2)
2. Gắn thêm 1 disk dữ liệu vào `storage-vm` (để MinIO lưu data)
3. Tạo partition trên disk mới (dùng `fdisk` hoặc `parted`)
4. Format partition vừa tạo bằng `ext4`
5. Mount vào `/mnt/data`
6. Thêm vào `/etc/fstab` để auto-mount sau reboot
7. Kiểm tra: reboot VM → `df -h` vẫn thấy `/mnt/data` được mount

### Phase 2 — DNS & NTP

Sau phase này mọi VM giao tiếp qua hostname, không dùng IP nữa.

1. Trên `infra-vm`: cài `bind9`
2. Tạo zone file cho `corp.internal` — thêm A record cho từng VM (`infra`, `storage`, `app`, `client`, `minio`, `mariadb`, `mongo`, `redis`)
3. Cấu hình `/etc/bind/named.conf.local` trỏ vào zone file
4. Trên tất cả VM còn lại: sửa `/etc/resolv.conf` (hoặc `netplan`) trỏ nameserver về `infra-vm`
5. Kiểm tra từ `client-vm`: `nslookup app.corp.internal` trả về đúng IP
6. Trên `infra-vm`: cài `chrony`, cấu hình làm NTP server
7. Trên tất cả VM còn lại: cài `chrony`, trỏ server về `infra-vm`
8. Kiểm tra: `chronyc sources` hiện `infra-vm` là nguồn đồng bộ

### Phase 3 — Object Storage (MinIO)

1. Trên `storage-vm`: tạo thư mục data (`/mnt/data`)
2. Download và cài MinIO server binary
3. Tạo systemd unit file `/etc/systemd/system/minio.service`
4. Cấu hình `MINIO_VOLUMES`, `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`
5. `systemctl enable --now minio`
6. Mở MinIO console tại `http://minio.corp.internal:9001`, tạo bucket `healthcheck`
7. Kiểm tra: upload/download file qua console hoặc `mc` CLI

> **Advanced:** thay `storage-vm` bằng 4 disk riêng biệt, cấu hình MinIO erasure coding (`MINIO_VOLUMES="/mnt/disk{1...4}"`). Test: `umount /mnt/disk2` → MinIO vẫn hoạt động.

### Phase 4 — Databases

Tất cả cài trên `app-vm`, data lưu trên partition từ Phase 1.

**MariaDB**
1. Cài `mariadb-server`
2. Chạy `mysql_secure_installation` để đặt mật khẩu root
3. Tạo database `healthdb` và user `healthuser`
4. Kiểm tra kết nối được từ user vừa tạo
5. Backup bằng `mysqldump`

> **Advanced:** cấu hình primary/replica — sửa `bind-address`, `server-id`, `log_bin` trên primary; `CHANGE MASTER TO` trên replica. Kiểm tra: ghi vào primary → `SHOW SLAVE STATUS` trên replica hiện `Seconds_Behind_Master: 0`.

**MongoDB**
1. Cài MongoDB Community từ repo chính thức
2. Sửa `bindIp` trong `/etc/mongod.conf` để cho phép kết nối từ ngoài localhost
3. `systemctl enable --now mongod`
4. Kiểm tra: `mongosh --eval "db.adminCommand('ping')"`

> **Advanced:** cấu hình replica set 3 node — sửa `replication.replSetName` trên cả 3 VM, chạy `rs.initiate()` rồi `rs.add()`. Kiểm tra: `rs.stepDown()` → `rs.status()` hiện primary mới.

**Redis**
1. Cài `redis-server`
2. Cho phép kết nối từ ngoài localhost (sửa `bind` trong config)
3. Enable và start service
4. Kiểm tra từ `client-vm`: `redis-cli -h redis.corp.internal PING`

### Phase 5 — Web Service & TLS

1. Trên `app-vm`: cài `nginx`
2. Tạo self-signed CA và server certificate bằng `openssl`
3. Ký server cert bằng CA vừa tạo
4. Cấu hình Nginx với TLS và `proxy_pass` về Ping App
5. Cấu hình DNS: thêm A record `app.corp.internal` trỏ về `app-vm`
6. Trên `client-vm`: trust CA cert → mở browser vào `https://app.corp.internal`
7. Kiểm tra: Ping App dashboard hiện 4 card xanh (MariaDB, MongoDB, Redis, MinIO)

> **Advanced:** chạy Ping App trên 2 VM (`app-vm-1`, `app-vm-2`), cấu hình Nginx `upstream` với 2 backend. Kiểm tra: `systemctl stop pingapp` trên `app-vm-1` → dashboard vẫn load từ `client-vm`.

### Phase 6 — Packaging & Deployment

Ping App được **cung cấp sẵn bởi giảng viên** dưới dạng source code — xem tại [`pingapp/`](./pingapp).

1. Đọc source code, cài dependencies thủ công và chạy thử
2. Điền đúng hostname các service (từ Phase 2) vào file cấu hình
3. Viết `pingapp.service` systemd unit file
4. Kiểm tra service tự restart khi bị kill
5. Tạo cấu trúc thư mục `.deb` (`DEBIAN/control`, `DEBIAN/postinst`, `opt/pingapp/`, `etc/`)
6. Build package bằng `dpkg-deb`
7. Cài lên VM sạch bằng `apt install`
8. **Tiêu chí pass:** reboot VM → `systemctl status pingapp` running, dashboard hiện đúng

---

## Kiểm tra HA — HA Testing (Nâng cao)

Sau khi hoàn thành phần nâng cao, học viên phải demo khả năng chịu lỗi:

| Kịch bản | Cách kích hoạt | Kết quả mong đợi |
|---|---|---|
| MinIO mất 1 drive | `umount` một disk (`/mnt/disk2`) | MinIO vẫn phục vụ đọc/ghi, card xanh |
| MariaDB primary chết | `systemctl stop mariadb` trên primary | Replica vẫn đọc được; ghi lại các bước promote |
| MongoDB primary chết | `rs.stepDown()` hoặc kill process | Replica set tự bầu primary mới |
| Ping App instance chết | `systemctl stop pingapp` trên app-vm-1 | Nginx tự chuyển traffic sang app-vm-2 |

Mỗi kịch bản: chụp màn hình lúc lỗi → hệ thống vẫn chạy từ `client-vm` → recovery.

---

## Thời gian Ước tính

| Phase | Cơ bản | Nâng cao (điểm cộng) |
|---|---|---|
| Phase 1 — Disk & Partition | 1–2 giờ | — |
| Phase 2 — DNS + NTP | 2 giờ | — |
| Phase 3 — Object Storage | 1–2 giờ | +2 giờ (MinIO erasure) |
| Phase 4 — Databases | 3–4 giờ | +3 giờ (replication) |
| Phase 5 — Web + TLS | 2–3 giờ | +1 giờ (load balancing) |
| Phase 6 — Packaging | 2–3 giờ | — |
| HA Testing | — | +2 giờ |
| **Tổng** | **~15–19 giờ** | **~21–27 giờ** |

---

## Output và Tài liệu — Deliverables

Tất cả output nộp trong **một thư mục duy nhất** với cấu trúc sau (xem ví dụ tại [`submission-example/`](./submission-example)):

```
submission-example/
├── phase1-disk/
│   ├── screenshot-fdisk.png            # fdisk -l hiện partition mới
│   └── screenshot-fstab.png            # /etc/fstab + df -h sau reboot
├── phase2-network/
│   ├── screenshot-dns-zonefile.png     # /etc/bind/db.corp.internal được highlight
│   ├── screenshot-dns-nslookup.png     # kết quả nslookup từ client-vm
│   ├── screenshot-ntp-chrony.png       # output của chronyc sources
│   └── screenshot-ntp-clients.png      # các VM khác đã sync giờ
├── phase3-storage/
│   ├── screenshot-minio-console.png    # MinIO web UI với bucket
│   ├── screenshot-minio-upload.png     # upload file qua mc hoặc browser
│   └── screenshot-minio-service.png    # minio.service file được highlight
├── phase4-databases/
│   ├── screenshot-mariadb-query.png    # SHOW TABLES; SELECT result
│   ├── screenshot-mariadb-backup.png   # lệnh mysqldump và output
│   ├── screenshot-mongodb-query.png    # insertOne / find result
│   └── screenshot-redis-ping.png       # redis-cli PING + SET/GET
├── phase5-web/
│   ├── screenshot-nginx-config.png     # file nginx config được highlight
│   ├── screenshot-tls-browser.png      # browser hiện cert hợp lệ / ổ khoá
│   ├── screenshot-pingapp-ui.png       # Ping App dashboard qua HTTPS, 4 card xanh
│   └── screenshot-dns-resolve.png      # curl -v phân giải app.corp.internal
├── phase6-package/
│   ├── screenshot-deb-build.png        # output của dpkg-deb --build
│   ├── screenshot-deb-install.png      # apt install ./pingapp.deb
│   ├── screenshot-systemd-unit.png     # pingapp.service được highlight
│   └── screenshot-after-reboot.png     # systemctl status pingapp sau reboot
├── advanced-ha/                        # chỉ nộp nếu làm phần nâng cao
│   ├── screenshot-minio-drive-kill.png # umount 1 drive → MinIO vẫn xanh
│   ├── screenshot-mariadb-failover.png # stop primary → replica lên thay
│   ├── screenshot-mongo-election.png   # rs.status() hiện primary mới
│   └── screenshot-app-failover.png     # kill app-vm-1 → Nginx vẫn phục vụ
└── pingapp.deb                         # package build từ Phase 6
```

### Yêu cầu ảnh chụp màn hình

Mỗi ảnh cần:
- **Khoanh đỏ hoặc mũi tên** vào dòng cấu hình quan trọng
- Hiển thị **hostname** trong terminal prompt để biết đang ở VM nào
- Chụp cả **lệnh đã gõ** và **kết quả trả về**

---

## Thang điểm — Scoring

### Điểm pass (6/10) — hoàn thành Phase 1 → 6

| Phase | Mô tả | Điểm |
|---|---|---|
| Phase 1 | OS cài đúng, disk mount đúng, fstab hoạt động sau reboot | 1 |
| Phase 2 | DNS phân giải được hostname nội bộ, NTP sync đúng | 1 |
| Phase 3 | MinIO chạy, tạo được bucket, upload/download file | 1 |
| Phase 4 | MariaDB + MongoDB + Redis chạy, kết nối được từ app | 1 |
| Phase 5 | Nginx + TLS hoạt động, Ping App hiện 4 card xanh qua HTTPS | 1 |
| Phase 6 | `apt install ./pingapp.deb` → reboot → service tự chạy | 1 |
| **Tổng** | | **6/10** |

### Điểm cộng (tối đa +4) — advanced components

| Hạng mục | Yêu cầu | Điểm |
|---|---|---|
| MinIO erasure coding | 4-drive, demo umount 1 drive → MinIO vẫn xanh | +1 |
| MariaDB replication | Primary + replica sync, demo stop primary → replica readable | +1 |
| MongoDB replica set | 3 node, demo `rs.stepDown()` → primary mới tự bầu | +1 |
| Nginx load balance + HA | 2 app instance, demo kill 1 → traffic vẫn chạy | +1 |
| **Tổng tối đa** | | **10/10** |

