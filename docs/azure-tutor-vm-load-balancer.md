# Open edX Tutor k3s on Azure VM with Load Balancer

Use this path for staging when AKS and custom DNS are not available, but you still want Kubernetes.

Architecture:

```text
sslip.io hostname
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
- HTTP rule on port `80`
- HTTPS rule on port `443`
- SSH NAT rule on port `50023`
- Ubuntu 22.04 VM in the backend pool
- NSG rules for HTTP, HTTPS, SSH NAT, and Azure Load Balancer probes

## Hostnames

After deployment, copy the output `loadBalancerPublicIp`.

If the IP is `20.24.42.95`, use these hostnames:

```text
staging.20.24.42.95.sslip.io
studio-staging.20.24.42.95.sslip.io
apps.staging.20.24.42.95.sslip.io
```

Check that they resolve:

```bash
nslookup staging.<load-balancer-ip>.sslip.io
nslookup studio-staging.<load-balancer-ip>.sslip.io
nslookup apps.staging.<load-balancer-ip>.sslip.io
```

## SSH to the VM

Use the template output `sshCommand`, or:

```bash
ssh -p 50023 edxicei@<load-balancer-ip>
```

## Install Tutor on k3s

Clone this branch on the VM:

```bash
git clone --branch openedx-tutor https://github.com/matapandax/configuration.git
cd configuration
```

Prepare k3s, Tutor, Caddy, and MFE:

```bash
PLATFORM_NAME="Open edX Staging" \
LMS_HOST=staging.<load-balancer-ip>.sslip.io \
CMS_HOST=studio-staging.<load-balancer-ip>.sslip.io \
MFE_HOST=apps.staging.<load-balancer-ip>.sslip.io \
CONTACT_EMAIL=admin@example.com \
MODE=prepare \
./util/install/install-tutor-k3s-vm-lb.sh
```

After hostnames resolve, launch Open edX on k3s:

```bash
PLATFORM_NAME="Open edX Staging" \
LMS_HOST=staging.<load-balancer-ip>.sslip.io \
CMS_HOST=studio-staging.<load-balancer-ip>.sslip.io \
MFE_HOST=apps.staging.<load-balancer-ip>.sslip.io \
CONTACT_EMAIL=admin@example.com \
MODE=launch \
./util/install/install-tutor-k3s-vm-lb.sh
```

## Checks

```bash
export KUBECONFIG=$HOME/.kube/config
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
MFE_HOST=apps.staging.<load-balancer-ip>.sslip.io
```

MinIO is disabled by default on this single-VM k3s path to avoid public Load Balancer hairpin timeouts during LMS migrations.
