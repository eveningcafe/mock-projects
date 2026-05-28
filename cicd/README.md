# Đồ án — Stack công nghệ

| Hạng mục | Lựa chọn | Lý do |
|---|---|---|
| **Môi trường** | On-Cloud — AWS (Amazon Web Services) | Dẫn đầu thị trường, tài liệu phong phú, dễ dàng tích hợp các dịch vụ IaC và CI/CD. |
| **Hạ tầng** | Kubernetes (K8s) — Amazon EKS (Elastic Kubernetes Service) | Cung cấp khả năng điều phối container mạnh mẽ, tự động cân bằng tải, quản lý tài nguyên hiệu quả, giảm thiểu downtime. |
| **Công nghệ Backend** | Linh hoạt — Node.js/Express.js (API RESTful) | Phổ biến, hiệu năng cao, dễ dàng đóng gói Docker. |
| **Công nghệ Frontend** | Linh hoạt — React/Next.js/Vue.js | Framework hiện đại, tối ưu trải nghiệm người dùng, dễ dàng build tĩnh hoặc SSR. |
| **Cơ sở dữ liệu** | Managed Service — Amazon RDS for PostgreSQL | Giảm gánh nặng quản trị DB (backup, patching, failover tự động), bảo mật cao. |
| **Triển khai Code** | Automation (CI/CD) — Jenkins / GitLab CI/CD | Tự động hóa toàn bộ quy trình build, test, deploy, đảm bảo tốc độ và sự nhất quán. |
| **Xây dựng Hạ tầng** | IaC (Infrastructure as Code) — Terraform | Quản lý, tái tạo hạ tầng AWS bằng mã nguồn, loại bỏ sai sót thủ công, dễ dàng mở rộng. |

cicd :
![alt text](image.png)

kien truc he thong 
![alt text](image-1.png)

kien truc ung dung 

![alt text](image-2.png)

## Cấu trúc thư mục

```
cicd/
├── app/                       # Python Flask app + frontend tĩnh
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── static/index.html
├── k8s/
│   └── app.yaml               # Namespace + Secret + Deployment + Service + Ingress
├── k8s-install-jenkins.yaml   # Cài Jenkins on-cluster (chạy 1 lần)
├── terraform/                 # IaC: VPC + EKS + RDS + ECR
└── ci/
    └── Jenkinsfile            # Pipeline: Test → Build → Push ECR → Deploy EKS
```

## Tạo pipeline trên Jenkins

Sau khi `kubectl apply -f k8s-install-jenkins.yaml`, lấy URL và mật khẩu admin:

```bash
kubectl -n jenkins get svc jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl -n jenkins exec deploy/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword
```

**Setup ban đầu:**

1. Mở Jenkins URL trong browser → **Unlock Jenkins** → paste password.
2. **Install suggested plugins** (đợi 2-3 phút).
3. **Create First Admin User** → username/password tùy chọn.
4. **Instance URL** → giữ mặc định → Save.

**Tạo Pipeline job:**

5. Trang chủ → **New Item** → tên `cicd-demo` → chọn **Pipeline** → OK.
6. Trong job config, kéo xuống section **Pipeline**:
   - **Definition**: `Pipeline script from SCM`
   - **SCM**: `Git`
   - **Repository URL**: repo Git của project (vd `git@github.com:<user>/mock-projects.git`)
   - **Branch**: `*/main`
   - **Script Path**: `cicd/ci/Jenkinsfile`
7. **Save** → **Build Now**.

**Lưu ý**: image `jenkins/jenkins:lts` mặc định không có `docker`, `aws`, `kubectl`. Để pipeline chạy được cần một trong các cách:

- **Custom Jenkins image**: tự build image kế thừa `jenkins/jenkins:lts` cài thêm docker/aws/kubectl, push lên ECR, sửa deployment.
- **Kubernetes plugin + Pod templates**: cài plugin `kubernetes`, dùng `agent { kubernetes {...} }` trong Jenkinsfile để spawn pod chứa sẵn tools.

