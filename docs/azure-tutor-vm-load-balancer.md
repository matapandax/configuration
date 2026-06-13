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

```bash
az deployment group create \
  --resource-group <resource-group> \
  --template-file templates/stamp/template-tutor-vm-lb.json \
  --parameters @templates/stamp/parameters.tutor-vm-lb.example.json
```

The template creates:

- Standard public IP
- Azure Standard Load Balancer
- HTTP rule on port `80`
- HTTPS rule on port `443`
- SSH NAT rule on port `50022`
- Ubuntu 22.04 VM in the backend pool
- NSG rules for HTTP, HTTPS, SSH NAT, and Azure Load Balancer probes

## Azure DNS

After deployment, get the Load Balancer public IP from the template output or Azure Portal.

In Azure DNS zone, create these `A` records pointing to the Load Balancer public IP:

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

## SSH to the VM

Use the template output `sshCommand`, or:

```bash
ssh -p 50022 edxicei@<load-balancer-ip>
```

## Install Tutor

Clone this branch on the VM, then run:

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
