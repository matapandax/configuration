# Open edX Tutor Kubernetes on Azure AKS

This template creates the Azure foundation for a Tutor Kubernetes deployment:

- Azure Kubernetes Service with autoscaling Linux nodes
- Dedicated Azure Virtual Network with separate AKS and Application Gateway subnets
- Azure Standard Load Balancer for the public Tutor `caddy` endpoint
- Azure Container Registry for custom Tutor images
- Log Analytics integration
- AKS managed identity
- Tutor MFE plugin enabled by default

Tutor itself is applied after the AKS cluster exists. The public entry point is the Tutor `caddy` Kubernetes service with `type=LoadBalancer`; AKS provisions an Azure Standard Load Balancer and public IP for that service. DNS must point to this load balancer IP before HTTPS certificates can be issued.

The template also reserves an `appgw-subnet` for a future Azure Application Gateway or AGIC setup. That subnet is created now so the network architecture is ready, but the default Tutor route still uses the Caddy LoadBalancer service.

## Deploy Azure Resources

From the repository root:

```bash
az deployment group create \
  --resource-group <resource-group> \
  --template-file templates/stamp/template-tutor-k8s-aks.json \
  --parameters @templates/stamp/parameters.tutor-k8s-aks.example.json
```

For Azure Portal, upload `templates/stamp/template-tutor-k8s-aks.json` as a custom template and use `templates/stamp/parameters.tutor-k8s-aks.example.json` as the parameter reference.

## Prepare Tutor and DNS

Run this from a machine that has Azure CLI login access:

```bash
RESOURCE_GROUP=<resource-group> \
AKS_NAME=<cluster-name>-aks \
LMS_HOST=learn.example.com \
CMS_HOST=studio.example.com \
CONTACT_EMAIL=admin@example.com \
MFE_HOST=apps.example.com \
MODE=prepare \
./util/install/install-tutor-k8s-aks.sh
```

By default the script enables Tutor MFE and uses `apps.<LMS_HOST>` as `MFE_HOST`. Set `MFE_HOST` explicitly, as shown above, if you want a cleaner hostname such as `apps.example.com`.

The script starts only the Tutor `caddy` service first. This creates the Azure Load Balancer endpoint. Check the external IP:

```bash
kubectl --namespace openedx get services/caddy --output wide
```

Create DNS records:

- `LMS_HOST` A record points to the Caddy external IP
- `CMS_HOST` A record points to the same Caddy external IP
- `MFE_HOST` A record points to the same Caddy external IP. By default this is `apps.<LMS_HOST>`.
- If MinIO is enabled, point `minio.<LMS_HOST>` to the same external IP

## Launch Open edX

After DNS resolves:

```bash
RESOURCE_GROUP=<resource-group> \
AKS_NAME=<cluster-name>-aks \
LMS_HOST=learn.example.com \
CMS_HOST=studio.example.com \
CONTACT_EMAIL=admin@example.com \
MFE_HOST=apps.example.com \
MODE=launch \
./util/install/install-tutor-k8s-aks.sh
```

Useful checks:

```bash
tutor k8s status
kubectl --namespace openedx get pods
kubectl --namespace openedx get services/caddy
```

MFE checks:

```bash
tutor config printvalue MFE_HOST
tutor plugins list
```

If you build custom Tutor images and push them to the Azure Container Registry from this template, attach the registry to AKS:

```bash
az aks update \
  --resource-group <resource-group> \
  --name <cluster-name>-aks \
  --attach-acr <acr-name>
```

## Version Notes

The bootstrap script defaults to the latest stable Tutor package from pip:

```bash
TUTOR_PACKAGE_SPEC='tutor[full]'
```

Override `TUTOR_PACKAGE_SPEC` only if you intentionally need an older Open edX release. For example, Koa uses Tutor `v11`:

```bash
TUTOR_PACKAGE_SPEC='tutor[full]>=11.0.0,<12.0.0'
```

Koa on modern AKS may need extra compatibility work, so use the current Tutor release unless the platform must stay on Koa.
