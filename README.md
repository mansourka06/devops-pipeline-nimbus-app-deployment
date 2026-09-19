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

### 4. Kubernetes

```bash
kubectl apply -k kubernetes/overlays/dev
# ou pour la prod :
kubectl apply -k kubernetes/overlays/prod
```

### 5. Monitoring

```bash
cd monitoring
# voir monitoring/README.md pour la procédure complète
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f prometheus/values.yaml
kubectl apply -f prometheus/servicemonitor.yaml
kubectl apply -f prometheus/alerts.yaml
```

## Ce qui rend ce projet "automation-ready"

- **Modulaire** : chaque brique (Terraform modules, rôles Ansible, charts
  Helm) est réutilisable telle quelle pour un autre microservice.
- **Aucun secret en clair dans le code réel** — les placeholders sont
  documentés, avec le chemin vers Sealed Secrets / External Secrets / SOPS.
- **Autoscaling à deux niveaux** : HPA (pods, sur CPU/mémoire) et Cluster
  Autoscaler (nodes EC2, sur la capacité du cluster).
- **Observabilité native** : l'app expose `/metrics` dès le départ —
  brancher un nouveau microservice sur ce pipeline suffit à le rendre
  monitorable.

## Limites connues de cette livraison

- Le module Terraform pour l'instance EC2 Jenkins elle-même n'est pas
  inclus (l'accent a été mis sur EKS) — à ajouter selon vos préférences
  (spot instance, taille, etc.).
- Les exemples de mots de passe (Postgres démo, Grafana admin) sont des
  placeholders **à remplacer** avant tout déploiement réel.
- Testé localement (Node/Jest, syntaxe HCL/YAML/JSON) mais **pas déployé
  sur un vrai compte AWS** dans le cadre de cette livraison — à valider
  avec `terraform plan` sur votre compte avant `apply`.

## Author

- [Mansour KA](https://github.com/mansourka06)
