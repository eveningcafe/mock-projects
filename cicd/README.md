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

