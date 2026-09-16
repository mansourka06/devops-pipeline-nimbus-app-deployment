# Build, Test & Push — Nimbus

Procédure complète pour le Build de l'app, étape par étape.

## Prérequis

- **Docker** ou **Docker Desktop** , lancé
- Un compte [Docker Hub](https://hub.docker.com)
- Vérifier l'installation :

```bash
docker --version
docker info | grep Architecture
# → doit afficher "Architecture: aarch64" ou "arm64"
```

## Étape 1 — Sanity check applicatif (sans Docker)

```bash
cd app
npm install
npm test
```

Attendu : `Tests: 6 passed, 6 total`. Si ça échoue ici, ne pas continuer
tant que ce n'est pas corrigé — Docker ne fera qu'emballer le même bug.

## Étape 2 — Sanity check Docker natif (rapide, arm64 uniquement)

Avant le build multi-arch, plus lent, un aller-retour rapide en natif
pour valider que le Dockerfile fonctionne :

```bash
docker build -t nimbus:local .
docker run -d --name nimbus -p 3000:3000 nimbus:local
docker ps
docker logs nimbus
```

Attendu dans les logs : `Nimbus listening on port 3000`.

### Vérifier que le site est accessible

```bash
curl http://localhost:3000/health
# → {"status":"ok"}

curl http://localhost:3000/api/info
# → {"service":"nimbus","version":"1.0.0","hostname":"...","uptimeSeconds":...}

curl http://localhost:3000/metrics | grep nimbus_http_requests_total
```

Puis ouvrir **http://localhost:3000** dans le navigateur : la landing
page (gradient violet/turquoise, particules animées) doit s'afficher.

Si tout répond correctement, nettoyer avant de passer à la suite :

```bash
docker rm -f nimbus
```

## Étape 3 — Préparer buildx (une seule fois)

```bash
docker buildx version
docker buildx create --name multiarch-builder --use
docker buildx inspect --bootstrap
```

`--bootstrap` télécharge l'émulateur QEMU nécessaire pour construire la
variante `amd64` sur une puce ARM. Sur Mac M4, cette étape est nettement plus
rapide que sur les générations précédentes.

## Étape 4 — Login Docker Hub

```bash
docker login
```

## Étape 5 — Build multi-arch + push

Avec plusieurs plateformes, Docker ne peut pas charger le résultat dans
le cache local (`--load` ne fonctionne qu'en mono-plateforme) : il faut
pousser directement vers le registre avec `--push`.

Remplacer `TON_USER` par le nom d'utilisateur Docker Hub :

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t TON_USER/nimbus:latest \
  -t TON_USER/nimbus:v1.0.0 \
  --push \
  .
```

## Étape 6 — Vérifier le manifest multi-arch

```bash
docker buildx imagetools inspect TON_USER/nimbus:latest
```

Attendu : deux entrées, `linux/amd64` et `linux/arm64`.

## Étape 7 — Tester en tirant depuis Docker Hub (pas depuis le cache local)

```bash
docker pull TON_USER/nimbus:latest
docker run -d --name nimbus-from-hub -p 3000:3000 TON_USER/nimbus:latest
curl http://localhost:3000/health
curl http://localhost:3000/api/info
```

Le Mac tire automatiquement la variante `arm64` — c'est la preuve que le
manifest multi-arch fonctionne correctement.

Ouvrir de nouveau **http://localhost:3000** pour confirmation visuelle,
puis nettoyer :

```bash
docker rm -f nimbus-from-hub
```

## Récapitulatif des commandes

```bash
# 1. App
cd devops-complete-project/app
npm install && npm test

# 2. Sanity check Docker natif
docker build -t nimbus:local .
docker run -d --name nimbus -p 3000:3000 nimbus:local
curl http://localhost:3000/health
docker rm -f nimbus

# 3. buildx
docker buildx create --name multiarch-builder --use
docker buildx inspect --bootstrap

# 4. Login
docker login

# 5. Build multi-arch + push
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t TON_USER/nimbus:latest \
  -t TON_USER/nimbus:v1.0.0 \
  --push \
  .

# 6. Vérifier
docker buildx imagetools inspect TON_USER/nimbus:latest

# 7. Test depuis Docker Hub
docker pull TON_USER/nimbus:latest
docker run -d --name nimbus-from-hub -p 3000:3000 TON_USER/nimbus:latest
curl http://localhost:3000/health
docker rm -f nimbus-from-hub
```

## Prochaine étape

⚠️ Le `Jenkinsfile` du projet pousse actuellement vers **GHCR**
(`ghcr.io/...`), pas Docker Hub. Si le pipeline CI/CD doit pousser vers
Docker Hub à la place, mettre à jour :
- `jenkins/Jenkinsfile` (variable `IMAGE_NAME` / login registry)
- `kubernetes/base/kustomization.yaml` et les overlays (champ `images`)

pour pointer vers `TON_USER/nimbus` au lieu de
`ghcr.io/<repo>/nimbus-dev`.