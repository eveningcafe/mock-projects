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
├── k8s-install-jenkins.yaml   # Jenkins master (PVC gp3 + LoadBalancer)
├── terraform/                 # IaC: VPC + EKS + RDS + ECR + EBS CSI + EC2 build machine
└── ci/
    └── Jenkinsfile            # Pipeline chạy trên EC2 agent
```

## Kiến trúc CI/CD

- **Jenkins master**: chạy trên EKS, dữ liệu lưu PVC 10Gi (gp3). Không cài tool build, chỉ orchestrate.
- **EC2 build machine**: instance riêng (t3.medium, Ubuntu 22.04) đã cài sẵn `docker`, `aws`, `kubectl`, `java`. Đăng ký vào Jenkins làm JNLP agent với label `ec2-build`. IAM instance profile có `ECRPowerUser` + `eks:DescribeCluster`.
- **Pipeline** chạy trên EC2 agent → build Docker image local, push ECR, deploy lên EKS.

## Lệnh thường dùng

```bash
# URL Jenkins
kubectl -n jenkins get svc jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Initial admin password (lần đầu)
kubectl -n jenkins exec deploy/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword

# EC2 build machine
terraform -chdir=terraform output build_machine_public_ip
ssh -i terraform/build-machine-key.pem ubuntu@<EC2_IP>
```

## Setup Jenkins master (chạy 1 lần)

1. Mở Jenkins URL → **Unlock Jenkins** → paste initial admin password.
2. **Install suggested plugins** (đợi 2-3 phút).
3. **Create First Admin User** → username/password tùy chọn → Save.

## Đăng ký EC2 làm JNLP agent

Phía Jenkins:

1. **Manage Jenkins → Nodes → New Node**:
   - Node name: `ec2-build`
   - Type: `Permanent Agent` → Create.
2. Trong form node:
   - Remote root directory: `/home/ubuntu/jenkins`
   - **Labels**: `ec2-build`
   - **Launch method**: `Launch agent by connecting it to the controller`
   - Save.
3. Sau khi save, click vào node `ec2-build` → copy đoạn lệnh `java -jar agent.jar ...` (có chứa secret).

Phía EC2:

```bash
ssh -i terraform/build-machine-key.pem ubuntu@<EC2_IP>
mkdir -p ~/jenkins && cd ~/jenkins
curl -fsSL http://<JENKINS_URL>/jnlpJars/agent.jar -o agent.jar
# Paste lệnh đã copy ở bước Jenkins UI:
java -jar agent.jar -url http://<JENKINS_URL>/ -secret <SECRET> -name ec2-build -workDir /home/ubuntu/jenkins
```

Để agent chạy như systemd service (background):

```bash
sudo tee /etc/systemd/system/jenkins-agent.service > /dev/null <<EOF
[Unit]
Description=Jenkins JNLP Agent
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/jenkins
ExecStart=/usr/bin/java -jar /home/ubuntu/jenkins/agent.jar -url http://<JENKINS_URL>/ -secret <SECRET> -name ec2-build -workDir /home/ubuntu/jenkins
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now jenkins-agent
```

## Tạo Pipeline job

1. Jenkins trang chủ → **New Item** → tên `cicd-demo` → **Pipeline** → OK.
2. Trong job config, kéo xuống section **Pipeline**:
   - **Definition**: `Pipeline script from SCM`
   - **SCM**: `Git`
   - **Repository URL**: `https://github.com/<user>/mock-projects.git`
   - **Branch**: `*/main`
   - **Script Path**: `cicd/ci/Jenkinsfile`
3. Tick **GitHub hook trigger for GITScm polling** → **Save** → **Build Now**.

## Auto-trigger khi push code (GitHub webhook)

Repo GitHub → Settings → **Webhooks** → **Add webhook**:

- **Payload URL**: `http://<JENKINS_URL>/github-webhook/`
- **Content type**: `application/json`
- **Which events**: `Just the push event`
- → **Add webhook**.

Sau khi add, mỗi `git push` sẽ trigger pipeline trong vài giây.
