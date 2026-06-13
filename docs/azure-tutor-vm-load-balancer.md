# Open edX Tutor on Azure VM with Load Balancer

Use this path when AKS/Kubernetes is not available yet but you still want an Azure Load Balancer in front of Open edX.

The architecture is:

```text
Azure DNS
  -> Azure Standard Load Balancer public IP
  -> Ubuntu VM
  -> Tutor Caddy
  -> Open edX LMS, Studio, MFE
```

## Deploy Azure Resources

For staging, use a separate resource group and the staging parameter file:

```bash
az deployment group create \
  --resource-group <staging-resource-group> \
  --template-file templates/stamp/template-tutor-vm-lb.json \
  --parameters @templates/stamp/parameters.tutor-vm-lb.staging.example.json
```

For production, use:

```bash
az deployment group create \
  --resource-group <resource-group> \
  --template-file templates/stamp/template-tutor-vm-lb.json \
  --parameters @templates/stamp/parameters.tutor-vm-lb.example.json
```

The template creates:

- Standard public IP
- Azure Standard Load Balancer
- Azure DNS zone and A records
- HTTP rule on port `80`
- HTTPS rule on port `443`
- SSH NAT rule on port `50022`
- Ubuntu 22.04 VM in the backend pool
- NSG rules for HTTP, HTTPS, SSH NAT, and Azure Load Balancer probes

## Azure DNS

The template creates an Azure DNS zone and the required `A` records automatically. Set `dnsZoneName` in the parameter file before deployment.

For staging, the default parameter file creates:

```text
dnsZoneName: iceiedx.id
lmsRecordName: staging
cmsRecordName: studio-staging
mfeRecordName: apps-staging
minioRecordName: minio.staging
```

Those become:

```text
staging.<zone>
studio-staging.<zone>
apps-staging.<zone>
minio.staging.<zone>
```

Example for staging on `iceiedx.id`:

```text
staging.iceiedx.id        A  <staging-load-balancer-ip>
studio-staging.iceiedx.id A  <staging-load-balancer-ip>
apps-staging.iceiedx.id   A  <staging-load-balancer-ip>
minio.staging.iceiedx.id  A  <staging-load-balancer-ip>
```

For production, the default parameter file creates:

```text
learn.<zone>
studio.<zone>
apps.<zone>
minio.learn.<zone>
```

Example for `iceiedx.id`:

```text
learn.iceiedx.id       A  <load-balancer-ip>
studio.iceiedx.id      A  <load-balancer-ip>
apps.iceiedx.id        A  <load-balancer-ip>
minio.learn.iceiedx.id A  <load-balancer-ip>
```

If the DNS zone is new, open the Azure DNS zone after deployment and copy its Azure nameservers to the domain registrar. DNS records will exist in Azure, but the public internet will only use them after the domain delegates to Azure DNS.

## SSH to the VM

For staging, use the template output `sshCommand`, or:

```bash
ssh -p 50023 edxicei@<staging-load-balancer-ip>
```

For production:

```bash
ssh -p 50022 edxicei@<load-balancer-ip>
```

## Install Tutor

Clone this branch on the VM, then run:

For staging:

```bash
git clone --branch openedx-tutor https://github.com/matapandax/configuration.git
cd configuration

PLATFORM_NAME="Open edX Staging" \
LMS_HOST=staging.iceiedx.id \
CMS_HOST=studio-staging.iceiedx.id \
MFE_HOST=apps-staging.iceiedx.id \
CONTACT_EMAIL=admin@iceiedx.id \
MODE=prepare \
./util/install/install-tutor-vm-lb.sh
```

After Azure DNS resolves, launch staging:

```bash
PLATFORM_NAME="Open edX Staging" \
LMS_HOST=staging.iceiedx.id \
CMS_HOST=studio-staging.iceiedx.id \
MFE_HOST=apps-staging.iceiedx.id \
CONTACT_EMAIL=admin@iceiedx.id \
MODE=launch \
./util/install/install-tutor-vm-lb.sh
```

For production:

```bash
git clone --branch openedx-tutor https://github.com/matapandax/configuration.git
cd configuration

LMS_HOST=learn.iceiedx.id \
CMS_HOST=studio.iceiedx.id \
MFE_HOST=apps.iceiedx.id \
CONTACT_EMAIL=admin@iceiedx.id \
MODE=prepare \
./util/install/install-tutor-vm-lb.sh
```

After Azure DNS resolves, launch Open edX:

```bash
LMS_HOST=learn.iceiedx.id \
CMS_HOST=studio.iceiedx.id \
MFE_HOST=apps.iceiedx.id \
CONTACT_EMAIL=admin@iceiedx.id \
MODE=launch \
./util/install/install-tutor-vm-lb.sh
```

The script uses the latest stable Tutor package by default:

```bash
TUTOR_PACKAGE_SPEC='tutor[full]'
```

MFE is enabled by default with:

```bash
ENABLE_MFE=1
MFE_HOST=apps.<LMS_HOST>
```
