# Jenkins CI/CD Setup

## Option A — Jenkins provisionné par Ansible sur EC2 (production)

Voir `ansible/playbooks/jenkins.yml`. Installe Jenkins, Docker, kubectl,
Helm et AWS CLI sur l'instance EC2 dédiée, provisionnée par Terraform.

## Option B — Jenkins local pour tester le pipeline (démo rapide)

```bash
docker compose -f jenkins/docker-compose.yml up -d
docker exec nimbus-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
# Ouvrir http://localhost:8080, coller le mot de passe, installer les plugins suggérés
```

## Configuration post-installation (les deux options)

1. **Plugins requis** (Manage Jenkins → Plugins) :
   `Git`, `GitHub`, `Docker Pipeline`, `Kubernetes CLI`, `Pipeline: AWS Steps`, `JUnit`

2. **Credentials** (Manage Jenkins → Credentials → System → Global) :
   | ID | Type | Valeur |
   |---|---|---|
   | `aws-credentials` | Username/password | Access key / secret key IAM (ou utiliser un rôle IAM sur l'instance) |
   | `github-token` | Secret text | Personal Access Token GitHub |

3. **Variables globales** (Manage Jenkins → System → Global properties → Environment variables) :
   | Nom | Exemple |
   |---|---|
   | `ECR_REPO_URL` | `123456789012.dkr.ecr.eu-west-1.amazonaws.com/nimbus-dev` (sortie Terraform `ecr_repository_url`) |
   | `EKS_CLUSTER_NAME` | `nimbus-dev-eks` (sortie Terraform `cluster_name`) |

4. **Créer le job** : New Item → Pipeline → "Pipeline script from SCM" →
   Git → URL du repo GitHub → Script Path: `jenkins/Jenkinsfile`

5. **Webhook GitHub** (déclenchement automatique) : Settings du repo
   GitHub → Webhooks → Add webhook → `http://<jenkins-host>:8080/github-webhook/`
   → content type `application/json` → event `push`

Une fois configuré, chaque push sur `main` déclenche automatiquement :
Checkout → Lint → Tests → Build image → Scan Trivy → Push ECR → Deploy EKS → Smoke test.
