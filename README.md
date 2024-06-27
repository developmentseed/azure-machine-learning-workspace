# azure-machine-learning-workspace

Terraform template for building an Azure Machine Learning Workspace

## Deploy the resources with Terraform

```shell
cd terraform
terraform init

terraform plan \
  -var "environment=spatio-ml" \
  -var "location=uksouth" \
  -var "prefix=hr" \
  -out demo.tfplan

terraform apply "demo.tfplan"
```
