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

## Cài đặt

### Yêu cầu

- `aws` CLI v2 đã login (`aws sso login` hoặc access key)
- `terraform` >= 1.5
- `kubectl` >= 1.31
- `docker` (chỉ cần để build/push image app lần đầu, sau đó EC2 agent lo)

### Bước 1 — Dựng hạ tầng

```bash
cd cicd/terraform
terraform init
terraform apply -var="db_password=ChangeMe1234!"
```

Tạo trong ~15 phút: VPC, EKS cluster + nodegroup, RDS, ECR, EBS CSI driver, EC2 build machine, IAM Access Entry.

Outputs:

```
cluster_name             = "cicd-demo-eks"
cluster_endpoint         = "https://...eks.amazonaws.com"
ecr_repository_url       = "<account>.dkr.ecr.ap-southeast-1.amazonaws.com/cicd-demo-app"
rds_endpoint             = "cicd-demo-db.<id>.ap-southeast-1.rds.amazonaws.com"
build_machine_public_ip  = "<EC2_IP>"
build_machine_ssh_key    = "./build-machine-key.pem"
kubeconfig_command       = "aws eks update-kubeconfig --region ap-southeast-1 --name cicd-demo-eks"
```

### Bước 2 — Cấu hình kubectl

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name cicd-demo-eks
kubectl get nodes   # 2 nodes Ready
```

### Bước 3 — Cài Nginx Ingress controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/aws/deploy.yaml
kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=180s
```

### Bước 4 — Cài Jenkins master

```bash
kubectl apply -f cicd/k8s-install-jenkins.yaml
kubectl -n jenkins rollout status deployment/jenkins --timeout=240s
```

### Bước 5 — Lấy các URL

```bash
# Jenkins
kubectl -n jenkins get svc jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# App (qua Nginx Ingress ALB)
kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Initial Jenkins admin password
kubectl -n jenkins exec deploy/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword
```

> Terraform không xuất Jenkins URL ra output vì LoadBalancer được Kubernetes provision sau, không phải Terraform. Dùng `kubectl` ở trên để lấy.

### Bước 6 — Setup Jenkins + EC2 agent + GitHub webhook

Xem các chương dưới: [Setup Jenkins master](#setup-jenkins-master-chạy-1-lần), [Đăng ký EC2 làm JNLP agent](#đăng-ký-ec2-làm-jnlp-agent), [Tạo Pipeline job](#tạo-pipeline-job), [Auto-trigger khi push code](#auto-trigger-khi-push-code-github-webhook).

> Pipeline chỉ làm `kubectl set image` — cần deployment tồn tại sẵn. Lần đầu phải `kubectl apply -f cicd/k8s/app.yaml` (sau khi sed thay `REPLACE_WITH_RDS_ENDPOINT` / `REPLACE_WITH_PASSWORD` / `REPLACE_WITH_ECR_URI:latest`). Sau đó pipeline tự lo các lần update tiếp theo.

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

## Dọn dẹp (Destroy)

⚠️ **Thứ tự quan trọng**: xóa Kubernetes Service type=LoadBalancer + PVC TRƯỚC khi `terraform destroy`. Nếu destroy terraform trước, AWS LoadBalancers (NLB/ALB) và EBS volume sẽ bị orphan và phát sinh phí.

```bash
# 1. Xóa app + ingress + jenkins (sẽ release các LoadBalancer + EBS volume)
kubectl delete -f cicd/k8s/app.yaml --ignore-not-found
kubectl delete -f cicd/k8s-install-jenkins.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/aws/deploy.yaml --ignore-not-found

# 2. Đợi vài chục giây cho AWS cleanup các LB
sleep 60

# 3. Destroy infrastructure
cd cicd/terraform
terraform destroy -var="db_password=ChangeMe1234!"
```

Kiểm tra sau khi xong:

```bash
aws elbv2 describe-load-balancers --region ap-southeast-1   # nên empty
aws ec2 describe-volumes --region ap-southeast-1 --filters Name=status,Values=available   # nên empty
```

Nếu vẫn còn LB/volume orphan: xóa thủ công qua AWS Console hoặc CLI để tránh chi phí.
