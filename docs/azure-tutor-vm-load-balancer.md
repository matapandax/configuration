# Open edX Tutor k3s on Azure VM with Load Balancer

Use this path for staging when AKS is not available but you still want Kubernetes.

Architecture:

```text
Azure DNS
  -> Azure Standard Load Balancer public IP
  -> Ubuntu VM
  -> k3s Kubernetes
  -> Tutor k8s Caddy
  -> Open edX LMS, Studio, MFE
```

## Deploy Staging Resources

Use a staging resource group and the staging parameter file:

```bash
az deployment group create \
  --resource-group <staging-resource-group> \
  --template-file templates/stamp/template-tutor-vm-lb.json \
  --parameters @templates/stamp/parameters.tutor-vm-lb.staging.example.json
```

The template creates:

- Standard public IP
- Azure Standard Load Balancer
- Azure DNS zone and A records
- HTTP rule on port `80`
- HTTPS rule on port `443`
- SSH NAT rule on port `50023`
- Ubuntu 22.04 VM in the backend pool
- NSG rules for HTTP, HTTPS, SSH NAT, and Azure Load Balancer probes

## Azure DNS

The staging parameter file creates these records in `iceiedx.id`:

```text
staging.iceiedx.id
studio-staging.iceiedx.id
apps-staging.iceiedx.id
minio.staging.iceiedx.id
```

All records point to the Azure Load Balancer public IP.

If the DNS zone is new, open the Azure DNS zone after deployment and copy its Azure nameservers to the domain registrar. DNS records will exist in Azure, but the public internet will only use them after the domain delegates to Azure DNS.

## SSH to the VM

Use the template output `sshCommand`, or:

```bash
ssh -p 50023 edxicei@<staging-load-balancer-ip>
```

## Install Tutor on k3s

Clone this branch on the VM:

```bash
git clone --branch openedx-tutor https://github.com/matapandax/configuration.git
cd configuration
```

Prepare k3s, Tutor, Caddy, MFE, and MinIO:

```bash
PLATFORM_NAME="Open edX Staging" \
LMS_HOST=staging.iceiedx.id \
CMS_HOST=studio-staging.iceiedx.id \
MFE_HOST=apps-staging.iceiedx.id \
CONTACT_EMAIL=admin@iceiedx.id \
MODE=prepare \
./util/install/install-tutor-k3s-vm-lb.sh
```

After DNS resolves, launch Open edX on k3s:

```bash
PLATFORM_NAME="Open edX Staging" \
LMS_HOST=staging.iceiedx.id \
CMS_HOST=studio-staging.iceiedx.id \
MFE_HOST=apps-staging.iceiedx.id \
CONTACT_EMAIL=admin@iceiedx.id \
MODE=launch \
./util/install/install-tutor-k3s-vm-lb.sh
```

## Checks

```bash
kubectl get nodes
kubectl --namespace openedx get pods,svc
tutor k8s status
```

The script uses the latest stable Tutor package by default:

```bash
TUTOR_PACKAGE_SPEC='tutor[full]'
```

MFE is enabled by default:

```bash
ENABLE_MFE=1
MFE_HOST=apps-staging.iceiedx.id
```
