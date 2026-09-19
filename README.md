# devops-pipeline-nimbus-app-deployment

## Description : **Nimbus — Complete DevOps Reference Project**

Un projet DevOps de bout en bout, codifié et réutilisable pour n'importe
quel microservice : **Terraform** (infra AWS), **Ansible** (config des
serveurs), **Jenkins** (CI/CD), **Docker + Kubernetes/EKS**
(conteneurisation et orchestration), **Prometheus + Grafana**
(monitoring).

L'application de démonstration, **Nimbus**, sert de fil rouge : c'est le
même code qui traverse chaque brique du pipeline.

## Usage

- Build & test de l'app Nimbus via docker: [doc](app/Readme-Run-App.md)


## Architecture

```
 Developer                                                              
    │ git push                                                         
    ▼                                                                  
 GitHub  ──webhook──▶  Jenkins (EC2, provisionné par Terraform,        
                        configuré par Ansible)                         
                        │                                               
                        ├─ 1. Checkout                                  
                        ├─ 2. Install & Lint                            
                        ├─ 3. Unit Tests (Jest)                         
                        ├─ 4. Build Docker Image                        
                        ├─ 5. Security Scan (Trivy)                     
                        ├─ 6. Push to ECR                                
                        ├─ 7. Deploy to EKS (kubectl set image)          
                        └─ 8. Smoke Test                                 
                                    │                                    
                                    ▼                                    
                    EKS Cluster (VPC/subnets/IAM via Terraform)          
                    ├─ Node Group (autoscaling 2→6, Cluster Autoscaler)  
                    ├─ Deployment "nimbus" (2+ replicas, HPA 2→10)       
                    ├─ Service + Ingress (ALB)                           
                    └─ ServiceAccount (IRSA)                             
                                    │                                    
                                    ▼                                    
                    Prometheus (scrape /metrics) ──▶ Grafana Dashboards  
                    Alertmanager (NimbusHighErrorRate, NimbusPodDown...) 
```

## Structure du repo

```
app/            Application Nimbus (Node.js/Express) — la "belle" démo
terraform/      IaC: VPC, IAM, EKS (autoscaling), ECR, Cluster Autoscaler
ansible/        Config management: Docker, Jenkins, kubectl/Helm/AWS CLI
jenkins/        Jenkinsfile + setup local pour tester le pipeline
kubernetes/     Manifests Kustomize (base + overlays dev/prod)
monitoring/     Prometheus (values, ServiceMonitor, alertes) + Grafana (dashboard)
```

## Déploiement de bout en bout, dans l'ordre

### 1. Infrastructure (Terraform)

```bash
cd terraform
./bootstrap-backend.sh          # une seule fois: crée le bucket S3 + table DynamoDB
terraform init
terraform plan  -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

Ceci provisionne : VPC (3 AZ, subnets public/privé, NAT), rôles IAM,
cluster EKS avec node group autoscaling (2→6 nodes), add-ons (VPC CNI,
CoreDNS, EBS CSI), le registre ECR, et déploie le Cluster Autoscaler
via Helm.

```bash
aws eks update-kubeconfig --region eu-west-1 --name nimbus-dev-eks
```

### 2. Serveur Jenkins (Ansible)

Provisionner une instance EC2 (via Terraform, non inclus ici pour rester
focalisé — un module `terraform/modules/jenkins-ec2` peut être ajouté),
puis :

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

Installe Docker, Jenkins, kubectl, Helm, AWS CLI et node_exporter sur le
serveur. Voir `jenkins/README.md` pour la configuration post-installation
(plugins, credentials, création du job).

### 3. Application (Docker + Jenkins)

Chaque push sur `main` déclenche `jenkins/Jenkinsfile` : tests → build
Docker → scan Trivy → push ECR → déploiement sur EKS → smoke test.

Pour tester l'app en local avant tout ça :

```bash
cd app
npm install
npm test              # 6 tests, ~94% de couverture
npm start             # http://localhost:3000
docker build -t nimbus .
```

## Author

- [Mansour KA](https://github.com/mansourka06)
