# terraform-aws-security

Platform identities, encryption keys and permanent cloud firewall rules of one Aroma Pacifico environment. Other modules create no role, key or security group, so they receive identifiers from this one, and each permission can be reviewed in a single place. It implements boxes C05 and C06 of the implementation scope.

The current release creates the keys and the platform roles of box C05. The endpoint security groups of box C06 arrive in a later minor release, together with the inputs they need.

## Contents

- [What it creates](#what-it-creates)
- [What it leaves to other places](#what-it-leaves-to-other-places)
- [Permissions of each role](#permissions-of-each-role)
- [Design choices](#design-choices)
- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Endpoint security groups](#endpoint-security-groups)
- [Destroying an environment](#destroying-an-environment)
- [Cost](#cost)
- [Pending confirmations](#pending-confirmations)
- [Infrastructure code rules](#infrastructure-code-rules)
- [Develop and test](#develop-and-test)
- [Versions](#versions)
- [Sources](#sources)

| Term | Meaning |
|---|---|
| Customer managed key | KMS key the platform creates and controls, with its own key policy |
| Trust policy | Policy of a role that says which service may assume it |
| Confused deputy | A service acting for another account or resource than the one intended. Source conditions in a trust policy prevent it |
| `kms:ViaService` | Condition that lets a role use a key only through the named AWS service, such as DynamoDB or S3 |

## What it creates

| Resource | Purpose |
|---|---|
| Data key | KMS key for the DynamoDB tables and the queues and topics of telemetry |
| Objects key | KMS key for the S3 buckets, separate so that access to objects can be cut without touching the data |
| Ingestion function role | Reads the queue, writes readings and alerts, reads ranges and publishes alerts |
| IoT rule role | Sends to one queue and one delivery stream |
| Firehose delivery role | Writes to the telemetry archive |
| Focus confirmation function role | Reads one bucket prefix, detects labels, moves objects with a person to the restricted prefix, invokes one model and writes results |

Each key has an alias, yearly rotation and an explicit key policy. Each role has one inline policy, and Terraform removes any other inline policy that appears on it.

## What it leaves to other places

| Need | Where it lives | Why |
|---|---|---|
| Platform key | Bootstrap of the infrastructure repository | It encrypts the state, which has to exist before this module runs |
| Pipeline roles | Bootstrap and pipeline of the infrastructure repository | A pipeline cannot create the role it needs in order to run |
| VPN tunnel keys | Secret that AWS creates with the connection | The code declares no secret |
| Human access | Landing zone design | The code covers platform identities only |
| Queues, tables, topics, streams, buckets and log groups | Workload modules | This module only names them in policies |

## Permissions of each role

The module owns the actions of every role, and the root only names the targets. No action holds a wildcard. The only resource `*` belongs to Rekognition `DetectLabels`, an action that IAM cannot scope to a resource.

| Role | Trusted service | Allowed actions | Targets |
|---|---|---|---|
| Ingestion function | Lambda | Receive and delete messages, read queue attributes | Ingestion queue |
| | | Put and batch write items | Readings and alerts tables |
| | | Get items and query | Ranges table and its indexes |
| | | Publish | Alert topic |
| | | Create log streams and put log events | Its own log group |
| IoT rule | IoT Core, from this account and the named rule only | Send messages | Ingestion queue |
| | | Put records | Archive delivery stream |
| Firehose delivery | Firehose | Put, get and abort multipart uploads of objects | Archive bucket objects |
| | | Get location, list objects and multipart uploads | Archive bucket |
| | | Put log events, only when a log group is given | Its delivery log group |
| Focus confirmation function | Lambda | Get and delete objects | Focus prefix of the flight object bucket |
| | | Put objects | Restricted prefix of the same bucket |
| | | Detect labels | Any, as IAM requires |
| | | Invoke model | Nova 2 Lite inference profile and its foundation model in the Regions the profile routes to |
| | | Put items | Cases table |
| | | Send messages | Its dead letter queue |
| | | Create log streams and put log events | Its own log group |

Key use is granted per service. A role may use the data key only through SQS, DynamoDB or SNS, and the objects key only through S3. For S3 the encryption context must also be the bucket the role works with, which is the bucket ARN because buckets use S3 Bucket Keys.

| Role | Data key | Objects key |
|---|---|---|
| Ingestion function | Decrypt through SQS. Decrypt, encrypt, generate data key and describe through DynamoDB. Decrypt and generate data key through SNS | None |
| IoT rule | Decrypt and generate data key through SQS | None |
| Firehose delivery | None | Decrypt and generate data key through S3, archive bucket only |
| Focus confirmation function | Decrypt, encrypt, generate data key and describe through DynamoDB. Decrypt and generate data key through SQS | Decrypt and generate data key through S3, flight object bucket only |

## Design choices

**Policies built as data.** Policies are Terraform objects in `locals.tf`, rendered with `jsonencode`. The tests read every action, resource and condition at plan time with no AWS account, so "no global permissions" is a tested property. The usual policy document data source would give random text under the test mock, and least privilege could then only be read by eye.

**Fixed purposes.** `roles` accepts exactly four purposes. The root names targets, and validation rejects an unknown purpose, a missing target, a target the purpose does not use, any wildcard in an ARN and a role name longer than 28 characters. A generic map of statements was discarded, because each environment root would then hold its own permissions and least privilege would be reviewed three times.

**Key policy.** Each key policy holds the account root statement of the AWS default key policy, so IAM policies decide who uses the key. A key may also list AWS service principals, which can use it only for this account. Naming the roles in the key policy was discarded, because it would repeat what the role policies say and tie the key to the roles.

**Trust conditions.** The IoT rule role requires this account and the named topic rule as source, as AWS recommends for IoT Core. AWS documents no source condition for Lambda execution roles or Firehose delivery roles, and adding one that the service does not send would stop it from assuming the role.

**Objects with a person.** Rekognition runs before any analysis, and when it finds a person the function copies the object to the restricted prefix and deletes the original, so the object never reaches the model. The role may write only to the restricted prefix and delete only in its own prefix. It cannot read the restricted prefix, which stays reserved to the platform operator.

**Account, Region and partition.** The module reads them through generic data sources, so the root passes no account number. These data sources look up nothing outside the provider's own context.

## Usage

Use the latest released tag in place of `v0.3.0`.

```hcl
module "security" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-security.git?ref=v0.3.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  keys  = local.keys
  roles = local.roles
}
```

The root builds the names of every resource, so it also knows their ARNs. It passes them inside `roles`, which lets a role name the queue or table it reaches without waiting for the workload module to create them. `sample/locals.tf` shows the full structure for one environment.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `client`, `project`, `environment` | `string` | Yes | Codes for names and tags. `environment` is `dev`, `test` or `prod` |
| `additional_tags` | `map(string)` | No | Tags added on top of the provider default tags |
| `keys` | `map(object)` | Yes | Exactly `data` and `objects`, each with `alias`, `description`, `deletion_window_in_days` (7 to 30, default 30) and optional `service_principals` |
| `roles` | `map(object)` | Yes | Exactly the four purposes below, each with `name` and its targets |

| Purpose | Required targets | Optional targets |
|---|---|---|
| `ingestion_function` | `queue_arns`, `write_table_arns`, `read_table_arns`, `topic_arns`, `log_group_arns` | None |
| `iot_rule` | `queue_arns`, `stream_arns`, `source_arn` | None |
| `firehose_delivery` | `bucket_arns` | `log_group_arns` |
| `focus_function` | `bucket_arns`, `object_prefix`, `restricted_prefix`, `model_arns`, `write_table_arns`, `dead_letter_queue_arns`, `log_group_arns` | None |

ARNs are complete, with no wildcard. Bucket ARNs carry no object path, log group ARNs carry no trailing `:*`, and both prefixes end with `/`. The focus and restricted prefixes may not contain each other, so a moved object never lands where the function reads. IoT rule names accept only letters, digits and underscores, so `source_arn` uses names such as `fnc_aroma_dev_rule_telemetry`.

## Outputs

| Name | Description |
|---|---|
| `data_key_arn` | ARN of the data key |
| `objects_key_arn` | ARN of the objects key |
| `ingestion_function_role_arn` | ARN of the ingestion function role |
| `iot_rule_role_arn` | ARN of the IoT rule role |
| `firehose_role_arn` | ARN of the Firehose delivery role |
| `focus_function_role_arn` | ARN of the focus confirmation function role |

## Endpoint security groups

The next minor release adds the security groups of the interface endpoints, with default deny and TCP 443 from the logistics and local server ranges of the centers. It adds the inputs `vpc_id` and `center_source_cidrs` and the output `endpoint_security_group_ids`. Only rules marked as permanent in the firewall matrix become code, each as a separate resource, which gives every rule its own identity in a plan.

## Destroying an environment

In the demonstration every environment, production included, is destroyed each night and rebuilt, so the keys carry no protection against destroy. A destroyed key waits for its deletion window before KMS removes it, and it cannot be used meanwhile. The window is 7 days in development and test and 30 in production. Aliases are deleted at once, and key names include the environment, so an environment can come back up the same day with new keys.

## Cost

| Item | Rate | Monthly cost per environment |
|---|---|---|
| Customer managed keys | USD 1 per key per month, prorated hourly | USD 2.00 for two keys |
| Automatic rotation | The first and the second rotation each add USD 1 per key per month, and later rotations add nothing | USD 0.00 while environments are rebuilt each night, since a key never reaches its first yearly rotation |
| Key requests | USD 0.03 per 10,000 requests, after 20,000 free per month counted across all Regions | Depends on workload traffic. Bucket Keys and the DynamoDB key cache keep requests low, and the platform cost analysis holds the figure |
| Key scheduled for deletion | No charge | USD 0.00 |
| Roles and policies | No charge | USD 0.00 |

A rebuilt environment creates new keys, and each one is billed for the hours it exists, so nightly rebuilds do not multiply the monthly figure. In a pilot that keeps its keys, a key kept for more than a year would cost USD 2 per month, and USD 3 per month after its second rotation.

## Pending confirmations

| Item | Current choice | If it is wrong |
|---|---|---|
| KMS actions a role needs to read and write items in a table under a customer managed key | Decrypt, encrypt, generate data key and describe, through DynamoDB | Calls fail with an access error, or a role holds an action it does not use. A test against the real service in the development environment settles it |
| How Rekognition reads an encrypted object | The focus role holds get object and decrypt on its prefix, which covers both reading the object itself and passing its S3 location | No change for either path |
| Workload encryption | Queues, tables and the alert topic use the data key, buckets use the objects key | The KMS statements of the affected role name another key |
| Model invocation | Nova 2 Lite through the US cross-Region inference profile | The focus role names other model ARNs |
| Function log groups | Named `/aws/lambda/<function name>` and created by the workload modules | The roles name other log ARNs |

## Infrastructure code rules

| Rule | How this module meets it |
|---|---|
| PC-IAC-002 Variables | Every input has a type, description and validation. `keys` and `roles` are `map(object)` with `optional()` and cross-field checks |
| PC-IAC-004 Tags | Each resource sets `Name` plus `additional_tags`, on top of the provider default tags |
| PC-IAC-005 Providers | Every resource and data source uses `aws.project` from the caller |
| PC-IAC-010 `for_each` | Keys, aliases, roles and policies iterate over maps. No `prevent_destroy`, see exceptions |
| PC-IAC-011 Data sources | Only generic ones for account, Region and partition |
| PC-IAC-016 Secrets | No secret input, value or output |
| PC-IAC-020 Security | Rotating keys, least privilege per role, the single resource `*` recorded as an exception |
| PC-IAC-023 Own service | Only KMS and IAM resources |
| PC-IAC-025 Names | The root passes every final name. The module adds none |
| PC-IAC-026 Sample | `tfvars`, variables, data, locals, then the module call |

## Develop and test

The exact Terraform version lives in `.terraform-version`. Tests run against a mocked provider, so they need no AWS account and spend no credits. They cover the validations, the key policies, the trust policies, every permission statement and the outputs.

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

## Sources

| Fact | Source |
|---|---|
| Actions, resource types and condition keys | AWS service authorization reference, `servicereference.us-east-1.amazonaws.com/v1/<service>/<service>.json` |
| Lambda execution role and SQS event source permissions | https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html, https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-configure.html |
| IoT Core rule actions and source conditions | https://docs.aws.amazon.com/iot/latest/developerguide/cross-service-confused-deputy-prevention.html |
| Firehose access to S3 | https://docs.aws.amazon.com/firehose/latest/dev/controlling-access.html |
| SQS, SNS and DynamoDB with customer managed keys | https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-key-management.html, https://docs.aws.amazon.com/sns/latest/dg/sns-key-management.html, https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/encryption.usagenotes.html |
| S3 encryption context and Bucket Keys | https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html |
| Bedrock inference profile permissions | https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-prereq.html |
| KMS prices and deletion | https://aws.amazon.com/kms/pricing/, https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html |

## Related repositories

| Repository | Role |
|---|---|
| [`aromapacifico-devops-infra`](https://github.com/aromapacifico-devops/aromapacifico-devops-infra) | Roots of each environment, which consume this module |
| [`terraform-aws-module-template`](https://github.com/aromapacifico-devops/terraform-aws-module-template) | Template this repository was generated from |
| [`aromapacifico-devops-docs`](https://github.com/aromapacifico-devops/aromapacifico-devops-docs) | Architecture and design documents |
