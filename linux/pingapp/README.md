# Ping App

Web dashboard kiểm tra kết nối tới các service trong hạ tầng.
Dùng để verify setup và test HA — khi một service chết, card chuyển đỏ ngay.

---

## Endpoints

| URL | Mô tả |
|---|---|
| `http://<host>:5000/` | Dashboard UI, tự refresh mỗi 10 giây |
| `http://<host>:5000/health` | JSON response, dùng với `curl` hoặc script |

**Ví dụ `/health` response:**
```json
{
  "overall": "degraded",
  "services": {
    "mariadb": { "status": "ok",    "latency_ms": 2 },
    "mongodb": { "status": "error", "error": "Connection refused" },
    "redis":   { "status": "ok",    "latency_ms": 1 },
    "minio":   { "status": "ok",    "latency_ms": 5 }
  }
}
```
- `overall: ok` → HTTP 200
- `overall: degraded` → HTTP 503

---

## Giao tiếp qua Domain (DNS)

Vì đã có **bind9** trên `infra-vm` (Phase 2), tất cả VM trong mạng `corp.internal`
đều resolve được hostname của nhau — **không cần dùng IP**.

Các DNS record cần có trên `infra-vm`:

```
; /etc/bind/db.corp.internal
app      IN A  <IP của app-vm>
mariadb  IN A  <IP của app-vm>
mongo    IN A  <IP của app-vm>
redis    IN A  <IP của app-vm>
minio    IN A  <IP của storage-vm>
```

> Nếu MariaDB, MongoDB, Redis cùng chạy trên `app-vm` thì 4 record đầu
> trỏ về cùng một IP. Nếu tách VM riêng thì sửa IP tương ứng.

Kiểm tra DNS từ bất kỳ VM nào:
```bash
nslookup mariadb.corp.internal
nslookup minio.corp.internal
```

---

## Cấu hình

Tất cả config đặt trong `/etc/pingapp/pingapp.env` (sau khi cài .deb),
hoặc copy từ `.env.example` khi chạy tay.

```env
MARIADB_HOST=mariadb.corp.internal
MARIADB_PORT=3306
MARIADB_USER=healthuser
MARIADB_PASSWORD=secret
MARIADB_DB=healthdb

MONGO_HOST=mongo.corp.internal
MONGO_PORT=27017

REDIS_HOST=redis.corp.internal
REDIS_PORT=6379

MINIO_HOST=minio.corp.internal:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=healthcheck
```

---

## Chạy tay (development)

```bash
# 1. Cài dependencies
pip3 install -r requirements.txt

# 2. Set biến môi trường
cp .env.example .env
# sửa .env cho đúng IP/hostname

export $(cat .env | xargs)

# 3. Chạy
python3 app.py
```

Mở browser: `http://localhost:5000`

---

## Build và cài .deb (Phase 6)

```bash
# Từ thư mục mock-project/
bash build.sh
# → tạo ra pingapp_1.0_amd64.deb

# Cài lên app-vm
sudo apt install ./pingapp_1.0_amd64.deb
```

Sau khi cài, `postinst` tự động:
1. `pip3 install` dependencies
2. `systemctl enable pingapp` — bật autostart
3. `systemctl start pingapp` — khởi động ngay

Sửa config rồi restart:
```bash
sudo nano /etc/pingapp/pingapp.env
sudo systemctl restart pingapp
```

Kiểm tra service:
```bash
systemctl status pingapp
journalctl -u pingapp -f        # xem log realtime
```

---

## Test HA

Từ `client-vm`, chạy watch liên tục:
```bash
watch -n 2 curl -s http://app.corp.internal:5000/health
```

Sau đó thử kill từng service và quan sát:

| Hành động | Lệnh trên VM tương ứng | Kết quả mong đợi |
|---|---|---|
| Kill MariaDB | `sudo systemctl stop mariadb` | card `mariadb` → đỏ |
| Kill MongoDB | `sudo systemctl stop mongod` | card `mongodb` → đỏ |
| Kill Redis | `sudo systemctl stop redis` | card `redis` → đỏ |
| Kill MinIO | `sudo systemctl stop minio` | card `minio` → đỏ |
| Restart service | `sudo systemctl start <service>` | card → xanh lại |

*(Advanced)* Kill một drive MinIO rồi kiểm tra card `minio` vẫn xanh:
```bash
# Trên storage-vm — unmount một trong 4 drives
sudo umount /mnt/disk2
# Ping App vẫn xanh → erasure coding hoạt động
```
