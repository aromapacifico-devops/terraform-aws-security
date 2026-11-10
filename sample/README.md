# Sample

Smallest working call of this module, and the reference for how a root injects IDs and names. It uses local state and the values in `terraform.tfvars`.

It creates the data and objects keys and the four platform roles. `data.tf` reads the account, Region and partition, and `locals.tf` builds every name and ARN from them, so the values file holds no identifier. The queues, tables, topics, streams and buckets the roles name do not need to exist.

```bash
terraform init -backend=false
terraform validate
terraform plan
```

`terraform plan` needs AWS credentials. Set `deploy_role_arn` to assume a role, or leave it empty to use the local credentials.
