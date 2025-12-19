# Kubernetes Cluster Installation Guide

This guide provides step-by-step instructions to deploy the Seafile application stack on your Kubernetes cluster.

## Prerequisites

- Kubernetes cluster running (Talos/Proxmox)
- `kubectl` configured and connected to your cluster
- `helm` installed (for Ingress NGINX)

## Installation Order

### Phase 1: Infrastructure Foundation

#### 1.1 Install MetalLB (LoadBalancer Provider)
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s
```

#### 1.2 Configure MetalLB IP Pool
```bash
kubectl apply -f metalLB/LB-pool-1.yaml
```

#### 1.3 Configure MetalLB L2 Advertisement
```bash
kubectl apply -f metalLB/LB-l2-advertisement.yaml
```

---

### Phase 2: Cluster Add-ons

#### 2.1 Install Metrics Server
```bash
kubectl apply -f metalLB/metrics-server.yaml

# Verify installation
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=metrics-server \
  --timeout=90s
```

#### 2.2 Install cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=300s
```

#### 2.3 Create cert-manager ClusterIssuers

**Start with staging (recommended for testing):**
```bash
kubectl apply -f cert-manager/letsencrypt-staging.yaml
```

**After testing, switch to production:**
```bash
kubectl apply -f cert-manager/letsencrypt-prod.yaml
```

---

### Phase 3: Ingress Controller

#### 3.1 Create Ingress NGINX Namespace
```bash
kubectl apply -f ingress-nginx/00-namespace.yaml
```

#### 3.2 Install Ingress NGINX via Helm
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  -f ingress-nginx/01-ingress-nginx-values.yaml

# Wait for Ingress NGINX to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s
```

#### 3.3 Verify LoadBalancer IP Assignment
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Note the EXTERNAL-IP (e.g., 192.168.0.181)
```

---

### Phase 4: Application Namespace & Storage

#### 4.1 Create Application Namespace
```bash
kubectl apply -f namespace.yaml
```

#### 4.2 Create PersistentVolumes
```bash
kubectl apply -f pv.yaml
```

#### 4.3 Create PersistentVolumeClaims
```bash
kubectl apply -f pvc.yaml

# Verify PVCs are bound
kubectl get pvc -n seafile
```

---

### Phase 5: Secrets & Configuration

#### 5.1 Create MariaDB Secret
```bash
kubectl create secret generic mariadb-secret \
  --namespace=seafile \
  --from-literal=MARIADB_ROOT_PASSWORD='db_dev' \
  --from-literal=MARIADB_DATABASE='seafile' \
  --from-literal=MARIADB_USER='seafile' \
  --from-literal=MARIADB_PASSWORD='seafile_password' \
  --from-literal=MARIADB_AUTO_UPGRADE='yes'
```

#### 5.2 Create Seafile Secret
```bash
kubectl create secret generic seafile-secret \
  --namespace=seafile \
  --from-literal=DB_ROOT_PASSWD='db_dev' \
  --from-literal=MYSQL_USER_PASSWORD='seafile_password' \
  --from-literal=TIME_ZONE='Europe/Berlin' \
  --from-literal=SEAFILE_ADMIN_EMAIL='admin@seafile.com' \
  --from-literal=SEAFILE_ADMIN_PASSWORD='admin_password' \
  --from-literal=SEAFILE_SERVER_LETSENCRYPT='false' \
  --from-literal=SEAFILE_SERVER_HOSTNAME='filekeeper-local.tplinkdns.com' \
  --from-literal=SEAFILE_SERVER_PROTOCOL='https'
```

#### 5.3 Create Docker Registry Secret (if using private registry)
```bash
kubectl create secret docker-registry regcred \
  --namespace=seafile \
  --docker-server=docker.seadrive.org/seafileltd \
  --docker-username=seafile \
  --docker-password=YOUR_PASSWORD \
  --docker-email=your-email@example.com
```

#### 5.4 Create MariaDB ConfigMap
```bash
kubectl apply -f mariadb-config.yaml
```

---

### Phase 6: Database Layer

#### 6.1 Create MariaDB Headless Service
```bash
kubectl apply -f mariadb-headless-service.yaml
```

#### 6.2 Create MariaDB Regular Service
```bash
kubectl apply -f services.yaml
```

#### 6.3 Deploy MariaDB StatefulSet
```bash
kubectl apply -f mariadb-statefulset.yaml

# Wait for MariaDB to be ready
kubectl wait --namespace=seafile \
  --for=condition=ready pod \
  --selector=app=mariadb \
  --timeout=300s

# Verify MariaDB is running
kubectl get pods -n seafile -l app=mariadb
```

---

### Phase 7: Application Layer

#### 7.1 Deploy Memcached
```bash
kubectl apply -f memcached.yaml
```

#### 7.2 Deploy Seafile
```bash
kubectl apply -f seafile-deployment.yaml

# Wait for Seafile to be ready
kubectl wait --namespace=seafile \
  --for=condition=ready pod \
  --selector=app=seafile \
  --timeout=300s

# Check Seafile logs
kubectl logs -n seafile -l app=seafile --tail=50
```

---

### Phase 8: Ingress & External Access

#### 8.1 Update Ingress Configuration

**Before applying, uncomment annotations in `ingress.yaml`:**
- Uncomment all annotations
- Uncomment TLS section

#### 8.2 Apply Ingress Resource
```bash
kubectl apply -f ingress.yaml

# Verify ingress
kubectl get ingress -n seafile
kubectl describe ingress seafile-ingress -n seafile
```

---

## SSL Certificate Setup

### Option 1: Using cert-manager (Automatic)

#### Step 1: Ensure cert-manager is installed (Phase 2.2)

#### Step 2: Create ClusterIssuer

**For testing (staging):**
```bash
kubectl apply -f cert-manager/letsencrypt-staging.yaml
```

**For production:**
```bash
kubectl apply -f cert-manager/letsencrypt-prod.yaml
```

#### Step 3: Configure Ingress

**Edit `ingress.yaml` and ensure:**
- `cert-manager.io/cluster-issuer: "letsencrypt-prod"` annotation is uncommented
- TLS section is uncommented with your domain

**Apply:**
```bash
kubectl apply -f ingress.yaml
```

#### Step 4: Verify Certificate Creation
```bash
# Check certificate status
kubectl get certificate -n seafile

# Check certificate details
kubectl describe certificate seafile-tls-cert -n seafile

# Check certificate request
kubectl get certificaterequest -n seafile

# Check challenges (if using HTTP-01)
kubectl get challenges -n seafile
```

#### Step 5: Monitor Certificate Issuance
```bash
# Watch certificate status
kubectl get certificate -n seafile -w

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager --tail=50
```

#### Step 6: Test SSL Certificate
```bash
# Test HTTPS connection
curl -vI https://filekeeper-local.tplinkdns.com

# Check certificate details
openssl s_client -connect filekeeper-local.tplinkdns.com:443 -servername filekeeper-local.tplinkdns.com
```

### Option 2: Manual Certificate (If cert-manager not available)

#### Step 1: Generate Certificate
```bash
# Using certbot or your preferred method
certbot certonly --standalone -d filekeeper-local.tplinkdns.com
```

#### Step 2: Create Kubernetes TLS Secret
```bash
kubectl create secret tls seafile-tls-cert \
  --namespace=seafile \
  --cert=/etc/letsencrypt/live/filekeeper-local.tplinkdns.com/fullchain.pem \
  --key=/etc/letsencrypt/live/filekeeper-local.tplinkdns.com/privkey.pem
```

#### Step 3: Update Ingress
Ensure `ingress.yaml` has TLS section pointing to `seafile-tls-cert` secret.

---

## Complete Installation Script

```bash
#!/bin/bash
set -e

echo "🚀 Starting Kubernetes cluster installation..."

# Phase 1: Infrastructure
echo "📦 Phase 1: Installing infrastructure..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
kubectl apply -f metalLB/LB-pool-1.yaml
kubectl apply -f metalLB/LB-l2-advertisement.yaml

# Phase 2: Add-ons
echo "📦 Phase 2: Installing cluster add-ons..."
kubectl apply -f metalLB/metrics-server.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/instance=cert-manager --timeout=300s
kubectl apply -f cert-manager/letsencrypt-staging.yaml

# Phase 3: Ingress
echo "📦 Phase 3: Installing ingress controller..."
kubectl apply -f ingress-nginx/00-namespace.yaml
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  -f ingress-nginx/01-ingress-nginx-values.yaml

# Phase 4: Storage
echo "📦 Phase 4: Setting up storage..."
kubectl apply -f namespace.yaml
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml

# Phase 5: Secrets (⚠️ EDIT VALUES BEFORE RUNNING)
echo "⚠️  Phase 5: Creating secrets..."
echo "⚠️  Please create secrets manually using commands in Phase 5 above"
read -p "Press Enter after creating secrets to continue..."

# Phase 6: Database
echo "📦 Phase 6: Deploying database..."
kubectl apply -f mariadb-headless-service.yaml
kubectl apply -f services.yaml
kubectl apply -f mariadb-config.yaml
kubectl apply -f mariadb-statefulset.yaml
kubectl wait --namespace=seafile --for=condition=ready pod --selector=app=mariadb --timeout=300s

# Phase 7: Application
echo "📦 Phase 7: Deploying application..."
kubectl apply -f memcached.yaml
kubectl apply -f seafile-deployment.yaml

# Phase 8: Ingress
echo "📦 Phase 8: Configuring ingress..."
kubectl apply -f ingress.yaml

echo "✅ Installation complete!"
```

---

## Verification Commands

```bash
# Check all pods
kubectl get pods -n seafile

# Check services
kubectl get svc -n seafile
kubectl get svc -n ingress-nginx

# Check ingress
kubectl get ingress -n seafile

# Check PVCs
kubectl get pvc -n seafile

# Check endpoints
kubectl get endpoints -n seafile

# Check certificate (if using cert-manager)
kubectl get certificate -n seafile

# Test connectivity
kubectl exec -it <pod-name> -n seafile -- curl http://seafile.seafile.svc.cluster.local
```

---

## Troubleshooting

### Database Connection Issues
```bash
# Check MariaDB logs
kubectl logs -n seafile -l app=mariadb

# Verify user exists
kubectl exec -n seafile mariadb-0 -- mysql -uroot -pdb_dev -e "SELECT User, Host FROM mysql.user WHERE User='seafile';"

# Fix user password if needed
kubectl exec -n seafile mariadb-0 -- mysql -uroot -pdb_dev -e "ALTER USER 'seafile'@'%' IDENTIFIED BY 'seafile_password'; FLUSH PRIVILEGES;"
```

### Certificate Issues
```bash
# Check certificate status
kubectl describe certificate -n seafile seafile-tls-cert

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager

# Check challenges
kubectl get challenges -n seafile
kubectl describe challenge -n seafile
```

### Ingress Issues
```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Check ingress status
kubectl describe ingress -n seafile seafile-ingress
```

---

## Important Notes

1. **Secrets**: Replace placeholder values in secret creation commands with your actual passwords
2. **Domain**: Update `filekeeper-local.tplinkdns.com` with your actual domain in:
   - `ingress.yaml`
   - `seafile-secret` (SEAFILE_SERVER_HOSTNAME)
   - `cert-manager` ClusterIssuer email
3. **Port Forwarding**: Configure router to forward ports 80 and 443 to Ingress NGINX LoadBalancer IP
4. **DDNS**: Ensure your domain resolves to your public IP
5. **SSL**: Start with staging issuer, then switch to production after testing

---

## File Reference

| File | Purpose |
|------|---------|
| `namespace.yaml` | Application namespace |
| `pv.yaml` | Persistent volumes for data storage |
| `pvc.yaml` | Persistent volume claims |
| `mariadb-config.yaml` | MariaDB configuration |
| `mariadb-headless-service.yaml` | Headless service for StatefulSet |
| `mariadb-statefulset.yaml` | MariaDB database |
| `services.yaml` | Services for mariadb, memcached, seafile |
| `memcached.yaml` | Memcached cache |
| `seafile-deployment.yaml` | Seafile application |
| `ingress.yaml` | Ingress for external access |
| `metalLB/*.yaml` | MetalLB configuration |
| `cert-manager/*.yaml` | SSL certificate issuers |
| `ingress-nginx/*.yaml` | Ingress controller config |

---

**Last Updated**: 2025-12-18
