# Terraform Testbed for NGINX for Azure
It's the Bill Gates Cloud! (BGC)

This is a messy, unorganized place for us to play with configurations and test things out.  Do not expect a high degree of precision and professionalism here.
However, we do want to document as much as we can, and turn this into something clean and good eventually (under a different repo)

## Doing it
Authentication:

1. Download the `az` tool (see `.tool-versions`)
1. `az login`
1. `az account list`
1. Find the right `id` and copy it (it's a UUID)
1. `az account set --subscription <that uuid>`
1. (optional - for when you're terraform from CI or via a tool called atlantis) Create a service principle so your TF scripts don't have so many permissions. `az ad sp create-for-rbac --name <service_principal_name> --role Contributor --scopes /subscriptions/<subscription_id>`
1. Take the output (you won't be able to see it again) and set the following env vars:
  ```
  export ARM_SUBSCRIPTION_ID="<azure_subscription_id>"
  export ARM_TENANT_ID="<azure_subscription_tenant_id>"
  export ARM_CLIENT_ID="<service_principal_appid>"
  export ARM_CLIENT_SECRET="<service_principal_password>"
  ```

If you want to know more, peep this: 
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret

## Set up Terraform
Use [asdf](https://asdf-vm.com/guide/getting-started.html) to install it.  If you want to install it another way, you're on your own. Peep the `.tool-versions` file to see what version this repo expects you to use.

```shell
asdf install
```

```shell
terraform init`
```

Now you are all ready to Terraform your way to success.

## Planning and applying
```shell
cp config.tfvars.example config.tfvars
```
Adjust the `config.tfvars` file to suit your needs. Make sure to tag your resources appropriately.

Go into the `main.tf` file and comment out the `ingress` block in the `azurerm_container_app` resource.  The apply will hang if you don't do this.

```shell
terraform plan -var-file=config.tfvars` -out plan.mtfplan
```

Sweep your peepers over the plan and confirm that It Is Good.

`terraform apply "plan.mtfplan"`

Next, uncomment the `ingress` block and repeat the process.



