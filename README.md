# terraform-aws-security

Platform identities, encryption keys and permanent cloud firewall rules of one Aroma Pacifico environment. Other modules create no role, key or security group, so they receive identifiers from this one, and each permission can be reviewed in a single place. It implements boxes C05 and C06 of the implementation scope.

This repository holds the skeleton and the interface the module commits to. The resources arrive with the first release, and no version tag exists yet.

## What it creates

| Resource | Purpose |
|---|---|
| Data key | KMS key for the DynamoDB tables |
| Objects key | KMS key for the S3 buckets, separate so that access to objects can be cut without touching the data |
| Ingestion function role | Reads the queue, writes readings and alerts, reads ranges and publishes alerts |
| IoT rule role | Sends to one queue and one delivery stream |
| Firehose delivery role | Writes to the telemetry archive |
| Focus confirmation function role | Reads one bucket prefix, detects labels, invokes one model and writes results |
| Endpoint security groups | TCP 443 from the logistics and local server ranges of the centers, and nothing else |

Yearly rotation is on for each key. No role holds a wildcard action, and each one names the resources it reaches.

## What it leaves to other places

| Need | Where it lives | Why |
|---|---|---|
| Platform key | Bootstrap of the infrastructure repository | It encrypts the state, which has to exist before this module runs |
| Pipeline roles | Bootstrap of the infrastructure repository | A pipeline cannot create the role it needs in order to run |
| VPN tunnel keys | Secret that AWS creates with the connection | The code declares no secret |
| Human access | Landing zone design | The code covers platform identities only |

## Firewall rules

Only rules marked as permanent in the firewall matrix become code, with default deny. Rules are declared as separate resources per rule, which gives each one its own identity in a plan and avoids conflicts between inline blocks and attached rules.

## Usage

Use the latest released tag in place of `v1.0.0`.

```hcl
module "security" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-security.git?ref=v1.0.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  vpc_id = module.network.vpc_id

  keys                = local.keys
  roles               = local.roles
  center_source_cidrs = var.center_source_cidrs
}
```

The root builds the names of every resource, so it also knows their ARNs. It passes them inside `roles`, which lets a role name the queue or table it reaches without waiting for the workload module to create them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `client`, `project`, `environment`, `additional_tags` | Governance | See below | Codes for tags and the extra tags of the module. `additional_tags` is optional |
| `vpc_id` | `string` | Yes | VPC that holds the endpoint security groups |
| `keys` | `map(object)` | Yes | Alias and description of each key |
| `roles` | `map(object)` | Yes | Final name of each role and the ARNs it may reach |
| `center_source_cidrs` | `list(string)` | Yes | Logistics and local server ranges allowed to reach the endpoints |

## Outputs

| Name | Description |
|---|---|
| `data_key_arn` | ARN of the data key |
| `objects_key_arn` | ARN of the objects key |
| `ingestion_function_role_arn` | ARN of the ingestion function role |
| `iot_rule_role_arn` | ARN of the IoT rule role |
| `firehose_role_arn` | ARN of the Firehose delivery role |
| `focus_function_role_arn` | ARN of the focus confirmation function role |
| `endpoint_security_group_ids` | Security group of each interface endpoint |

## Destroying an environment

A KMS key waits at least 7 days before deletion. Aliases are deleted at once, and key names include the environment, so an environment can come back up the same day with new keys.

## Cost

Each customer managed key costs USD 1 per month. Roles and security groups have no charge.

## Develop and test

The exact Terraform version lives in `.terraform-version`. Tests run against a mocked provider, so they need no AWS account and spend no credits.

```bash
terraform init -backend=false
terraform test
terraform -chdir=sample init -backend=false
terraform -chdir=sample validate
```

`terraform validate` runs on `sample/` because this module declares the `aws.project` provider alias, which only receives a provider from a caller.

The shared checks of the organization cover format, tests, TFLint, Checkov and secret scanning. An accepted finding goes in `docs/iac-exceptions.md` with its reason and its end condition.

## Versions

Commits follow Conventional Commits, and they decide the next version. A `fix` raises the patch, a `feat` raises the minor, and a breaking change raises the major. Each release publishes an exact `vX.Y.Z` tag and updates `CHANGELOG.md`. Consumers pin that tag, so a new version reaches an environment only through a reviewed change in the infrastructure repository.

## Related repositories

| Repository | Role |
|---|---|
| [`aromapacifico-devops-infra`](https://github.com/aromapacifico-devops/aromapacifico-devops-infra) | Roots of each environment, which consume this module |
| [`terraform-aws-module-template`](https://github.com/aromapacifico-devops/terraform-aws-module-template) | Template this repository was generated from |
| [`aromapacifico-devops-docs`](https://github.com/aromapacifico-devops/aromapacifico-devops-docs) | Architecture and design documents |
