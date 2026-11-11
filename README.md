# terraform-aws-security

Platform identities, encryption keys and permanent cloud firewall rules of one Aroma Pacifico environment. Other modules create no role, key or security group, so they receive identifiers from this one, and each permission can be reviewed in a single place. It implements boxes C05 and C06 of the implementation scope.

Box C05 is the keys and the platform roles, including the roles of alert delivery. Box C06, "Firewall de nube", is the permanent rules of the firewall matrix in `docs/security/firewall-policy.md` of the documentation repository. They are created only when the root passes `firewall`.

## Contents

- [What it creates](#what-it-creates)
- [What it leaves to other places](#what-it-leaves-to-other-places)
- [Permissions of each role](#permissions-of-each-role)
- [Design choices](#design-choices)
- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Cloud firewall](#cloud-firewall)
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
| Network ACL | Stateless filter of a subnet. It checks each packet both ways and ends with a deny |
| Center source ranges | The logistics range `10.X.3.0/24` and the local server range `10.X.10.0/24` of each linked center |

## What it creates

| Resource | Purpose |
|---|---|
| Data key | KMS key for the DynamoDB tables and the queues of telemetry and alert delivery |
| Objects key | KMS key for the S3 buckets, separate so that access to objects can be cut without touching the data |
| Ingestion function role | Reads the queue, writes readings and alerts, reads ranges and farms, publishes alerts to the phones of a farm and queues a delivery check |
| IoT rule role | Sends to one queue and one delivery stream |
| Firehose delivery role | Reads the archive schema and writes Parquet files to the telemetry archive |
| Focus confirmation function role | Reads one bucket prefix, detects labels, moves objects with a person to the restricted prefix, invokes one model and writes results |
| Delivery status function role | Writes the push and SMS status of each alert, finding it through the index on the message identifier |
| Delivery check function role | Reads the delay queue, checks each alert after 5 minutes and sends the SMS of an urgent alert |
| Push status logs role | Lets SNS write the success and failure status of each push |
| SMS status logs role | Lets End User Messaging SMS write the events of its configuration set |
| Endpoint security groups (SG-01 to SG-04) | One group per interface endpoint, IoT Core data, S3 and private API. TCP 443 from each center range and no egress |
| Ingress network ACL (NACL-01 to NACL-03) | On the telemetry ingress, drone ingress and application subnets. TCP 443 in from each center range, return traffic out to it, deny for everything else |
| Closed network ACL (NACL-04) | On the data, object storage, administration and public query subnets. No allow rule |

Each key has an alias, yearly rotation and an explicit key policy. Each role has one inline policy, and Terraform removes any other inline policy that appears on it. In the same way, each endpoint group holds only the rules of this module, and a rule added in the console disappears at the next apply.

## What it leaves to other places

| Need | Where it lives | Why |
|---|---|---|
| Platform key | Bootstrap of the infrastructure repository | It encrypts the state, which has to exist before this module runs |
| Pipeline roles | Bootstrap and pipeline of the infrastructure repository | A pipeline cannot create the role it needs in order to run |
| VPN tunnel keys | Secret that AWS creates with the connection | The code declares no secret |
| Human access | Landing zone design | The code covers platform identities only |
| Default security group with no rules (SG-05) | Network module | It belongs to the VPC |
| Routes to the centers and the VPN | Network module | The ACLs only filter what the routes bring |
| Center firewall rules | Installation template of each center | They run on the center equipment |
| Temporary rules | The change process of the firewall policy | They are opened and closed by hand with an expiry |
| Queues, tables, platform applications, configuration sets, streams, buckets, Glue tables and log groups | Workload modules | This module only names them in policies |

## Permissions of each role

The module owns the actions of every role, and the root only names the targets. No action holds a wildcard. The only resource `*` belongs to Rekognition `DetectLabels`, an action that IAM cannot scope to a resource.

| Role | Trusted service | Allowed actions | Targets |
|---|---|---|---|
| Ingestion function | Lambda | Receive and delete messages, read queue attributes | Ingestion queue |
| | | Put, batch write, get and update items | Readings and alerts tables |
| | | Get items and query | Ranges and farm tables and their indexes |
| | | Publish | Endpoints of the push platform applications |
| | | Send messages | Delivery check queue |
| | | Create log streams and put log events | Its own log group |
| IoT rule | IoT Core, from this account and the named rule only | Send messages | Ingestion queue |
| | | Put records | Archive delivery stream |
| Firehose delivery | Firehose | Get table and its versions | Catalog, database and table of the archive schema |
| | | Put, get and abort multipart uploads of objects | Archive bucket objects |
| | | Get location, list objects and multipart uploads | Archive bucket |
| | | Put log events, only when a log group is given | Its delivery log group |
| Focus confirmation function | Lambda | Get and delete objects | Focus prefix of the flight object bucket |
| | | Put objects | Restricted prefix of the same bucket |
| | | Detect labels | Any, as IAM requires |
| | | Invoke model | Nova 2 Lite inference profile and its foundation model in the Regions the profile routes to |
| | | Put items | Cases table |
| | | Send messages | Its dead letter queue |
| | | Create log streams and put log events | Its own log group |
| Delivery status function | Lambda | Get and update items | Alerts table |
| | | Query | Indexes of the alerts table |
| | | Create log streams and put log events | Its own log group |
| Delivery check function | Lambda | Receive and delete messages, read queue attributes | Delivery check queue |
| | | Get and update items | Alerts table |
| | | Get items | Farm table, which holds the phone number |
| | | Send text messages | SMS configuration set and origination identities |
| | | Create log streams and put log events | Its own log group |
| Push status logs | SNS | Create log groups, create log streams and put log events | Success and failure log groups of each platform application |
| SMS status logs | End User Messaging SMS, from this account and the named configuration set only | Describe and create log streams, put log events | SMS status log group |

Key use is granted per service. A role may use the data key only through SQS or DynamoDB, and the objects key only through S3. For S3 the encryption context must also be the bucket the role works with, which is the bucket ARN because buckets use S3 Bucket Keys.

| Role | Data key | Objects key |
|---|---|---|
| Ingestion function | Decrypt and generate data key through SQS. Decrypt, encrypt, generate data key and describe through DynamoDB | None |
| IoT rule | Decrypt and generate data key through SQS | None |
| Firehose delivery | None | Decrypt and generate data key through S3, archive bucket only |
| Focus confirmation function | Decrypt, encrypt, generate data key and describe through DynamoDB. Decrypt and generate data key through SQS | Decrypt and generate data key through S3, flight object bucket only |
| Delivery status function | Decrypt, encrypt, generate data key and describe through DynamoDB | None |
| Delivery check function | Decrypt through SQS. Decrypt, encrypt, generate data key and describe through DynamoDB | None |

## Design choices

**Policies built as data.** Policies are Terraform objects in `locals.tf`, rendered with `jsonencode`. The tests read every action, resource and condition at plan time with no AWS account, so "no global permissions" is a tested property. The usual policy document data source would give random text under the test mock, and least privilege could then only be read by eye.

**Fixed purposes.** `roles` accepts exactly eight purposes. The root names targets, and validation rejects an unknown purpose, a missing target, a target the purpose does not use, any wildcard in an ARN and a role name longer than 28 characters. A generic map of statements was discarded, because each environment root would then hold its own permissions and least privilege would be reviewed three times.

**Key policy.** Each key policy holds the account root statement of the AWS default key policy, so IAM policies decide who uses the key. A key may also list AWS service principals, which can use it only for this account. Naming the roles in the key policy was discarded, because it would repeat what the role policies say and tie the key to the roles.

**Trust conditions.** The IoT rule role requires this account and the named topic rule as source, as AWS recommends for IoT Core, and the SMS status logs role requires this account and the named configuration set, as AWS recommends for End User Messaging SMS. AWS documents no source condition for Lambda execution roles, Firehose delivery roles or SNS delivery status roles, and adding one that the service does not send would stop it from assuming the role.

**Objects with a person.** Rekognition runs before any analysis, and when it finds a person the function copies the object to the restricted prefix and deletes the original, so the object never reaches the model. The role may write only to the restricted prefix and delete only in its own prefix. It cannot read the restricted prefix, which stays reserved to the platform operator.

**Alerts go to endpoints.** The ingestion function publishes each alert straight to the phone endpoints of a farm, which SNS creates under a platform application. The role names the endpoints of each application with `endpoint/<platform>/<application>/*`, derived from the application ARN, since endpoints appear when a farmer registers a phone. The alert delivery design publishes to the endpoints of the farm, so the role holds no topic.

**Metrics through logs.** The delivery functions publish their latency and undelivered figures in the embedded metric format of their own log, so no role needs `cloudwatch:PutMetricData`, which accepts no resource and would add a second resource `*`.

**Account, Region and partition.** The module reads them through generic data sources, so the root passes no account number. These data sources look up nothing outside the provider's own context.

## Usage

Use the latest released tag in place of `v0.5.0`.

```hcl
module "security" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-security.git?ref=v0.5.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  keys  = local.keys
  roles = local.roles

  firewall = {
    vpc_id                 = module.network.vpc_id
    open_subnet_ids        = local.open_subnet_ids
    closed_subnet_ids      = local.closed_subnet_ids
    center_cidrs           = local.center_cidrs
    enable_endpoint_groups = var.enable_private_endpoints
  }
}
```

The network module receives `module.security.endpoint_security_group_ids` for its interface endpoints. Terraform resolves both directions resource by resource, so the two calls form no cycle.

The root builds the names of every resource, so it also knows their ARNs. It passes them inside `roles`, which lets a role name the queue or table it reaches without waiting for the workload module to create them. `sample/locals.tf` shows the full structure for one environment.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `client`, `project`, `environment` | `string` | Yes | Codes for names and tags. `environment` is `dev`, `test` or `prod` |
| `additional_tags` | `map(string)` | No | Tags added on top of the provider default tags |
| `keys` | `map(object)` | Yes | Exactly `data` and `objects`, each with `alias`, `description`, `deletion_window_in_days` (7 to 30, default 30) and optional `service_principals` |
| `roles` | `map(object)` | Yes | Exactly the eight purposes below, each with `name` and its targets |
| `firewall` | `object` | No | `vpc_id`, `open_subnet_ids`, `closed_subnet_ids`, `center_cidrs` and `enable_endpoint_groups`. Default `null` creates no firewall resource |

| Purpose | Required targets | Optional targets |
|---|---|---|
| `ingestion_function` | `queue_arns`, `write_table_arns`, `read_table_arns`, `push_application_arns`, `send_queue_arns`, `log_group_arns` | None |
| `iot_rule` | `queue_arns`, `stream_arns`, `source_arn` | None |
| `firehose_delivery` | `bucket_arns`, `glue_table_arns` | `log_group_arns` |
| `focus_function` | `bucket_arns`, `object_prefix`, `restricted_prefix`, `model_arns`, `write_table_arns`, `dead_letter_queue_arns`, `log_group_arns` | None |
| `delivery_status_function` | `write_table_arns`, `log_group_arns` | None |
| `delivery_check_function` | `queue_arns`, `write_table_arns`, `read_table_arns`, `sms_resource_arns`, `log_group_arns` | None |
| `push_status_logs` | `log_group_arns` | None |
| `sms_status_logs` | `log_group_arns`, `source_arn` | None |

ARNs are complete, with no wildcard. Bucket ARNs carry no object path, log group ARNs carry no trailing `:*`, and both prefixes end with `/`. The focus and restricted prefixes may not contain each other, so a moved object never lands where the function reads. IoT rule names accept only letters, digits and underscores, so the `source_arn` of `iot_rule` uses names such as `fnc_aroma_dev_rule_telemetry`. The `source_arn` of `sms_status_logs` is the SMS configuration set, which `sms_resource_arns` must also include. Push applications are platform application ARNs, `app/GCM/<name>` or `app/APNS/<name>`, and Glue tables are `table/<database>/<table>`.

In `firewall`, each center range is a network address of /16 or narrower with no host bits, up to 20 ranges with no repeats, so `0.0.0.0/0` is rejected. A subnet may be open or closed, never both, and each list needs at least one subnet. `enable_endpoint_groups` follows `enable_private_endpoints` of the network module, since the groups exist only while the endpoints do.

## Outputs

| Name | Description |
|---|---|
| `data_key_arn` | ARN of the data key |
| `objects_key_arn` | ARN of the objects key |
| `ingestion_function_role_arn` | ARN of the ingestion function role |
| `iot_rule_role_arn` | ARN of the IoT rule role |
| `firehose_role_arn` | ARN of the Firehose delivery role |
| `focus_function_role_arn` | ARN of the focus confirmation function role |
| `delivery_status_function_role_arn` | ARN of the delivery status function role |
| `delivery_check_function_role_arn` | ARN of the delivery check function role |
| `push_status_logs_role_arn` | ARN of the role SNS uses for the success and failure feedback of each platform application |
| `sms_status_logs_role_arn` | ARN of the role End User Messaging SMS uses for the event destination of its configuration set |
| `endpoint_security_group_ids` | Group IDs keyed `iot_data`, `s3` and `private_api`, for the network module. Empty while the groups are off |

## Cloud firewall

Only rules marked permanent in the firewall matrix become code. Each rule is its own resource, so a plan shows every one by name and range.

| Rule | Resource | What it allows |
|---|---|---|
| SG-01 to SG-03 | `aws_vpc_security_group_ingress_rule.endpoints` | TCP 443 from each center range to the IoT Core data, S3 and private API endpoints |
| SG-04 | `aws_security_group.endpoints` with no egress, and `aws_vpc_security_group_rules_exclusive.endpoints` | Nothing out. Terraform removes the default egress rule of a new group, and the exclusive resource keeps egress empty |
| NACL-01 | `aws_network_acl_rule.center_in` | TCP 443 in from each center range, rule numbers from 100 in steps of 10 |
| NACL-02 | `aws_network_acl_rule.center_out` | TCP 1024 to 65535 out to each center range, which carries the responses |
| NACL-03 | `aws_network_acl.open` | Nothing else, through the final deny of the ACL |
| NACL-04 | `aws_network_acl.closed` | Nothing, since it holds no rule |

An environment with no linked center gets both ACLs and no allow rule, so its subnets admit nothing. Rule numbers follow the order of `center_cidrs`, so adding a center at the end leaves the existing rules in place. The root builds that list from the linked centers in a fixed order.

Associating a subnet with an ACL of this module takes it out of the default ACL of the VPC. Destroying the module returns it there.

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
| Security groups and network ACLs | No charge | USD 0.00 |

A rebuilt environment creates new keys, and each one is billed for the hours it exists, so nightly rebuilds do not multiply the monthly figure. In a pilot that keeps its keys, a key kept for more than a year would cost USD 2 per month, and USD 3 per month after its second rotation.

## Pending confirmations

| Item | Current choice | If it is wrong |
|---|---|---|
| KMS actions a role needs to read and write items in a table under a customer managed key | Decrypt, encrypt, generate data key and describe, through DynamoDB | Calls fail with an access error, or a role holds an action it does not use. A test against the real service in the development environment settles it |
| How Rekognition reads an encrypted object | The focus role holds get object and decrypt on its prefix, which covers both reading the object itself and passing its S3 location | No change for either path |
| Workload encryption | Queues and tables use the data key, buckets use the objects key | The KMS statements of the affected role name another key |
| Publish scoped to endpoint ARNs | The service reference lists only topics as the resource of `sns:Publish`, and the role names the endpoints of each application | A publish fails with an access error in the first deployment, and the statement moves to the resource `*` with an exception record |
| SNS push status log groups | Named `sns/<region>/<account>/app/<platform>/<application>` and the same name with `/Failure`, and the role is scoped to them where the AWS example uses all log groups | SNS writes no status and the role names the groups SNS really uses |
| SMS with no origination identity | The role names the configuration set, and a phone number, pool or sender ID once the short code exists | A send fails with an access error until the identity is added to `sms_resource_arns` |
| Model invocation | Nova 2 Lite through the US cross-Region inference profile | The focus role names other model ARNs |
| Function log groups | Named `/aws/lambda/<function name>` and created by the workload modules | The roles name other log ARNs |

## Infrastructure code rules

| Rule | How this module meets it |
|---|---|
| PC-IAC-002 Variables | Every input has a type, description and validation. `keys` and `roles` are `map(object)` with `optional()` and cross-field checks |
| PC-IAC-004 Tags | Each resource sets `Name` plus `additional_tags`, on top of the provider default tags |
| PC-IAC-005 Providers | Every resource and data source uses `aws.project` from the caller |
| PC-IAC-010 `for_each` | Keys, aliases, roles, policies, groups and rules iterate over maps. Each ACL uses `count` on the optional input. No `prevent_destroy`, see exceptions |
| PC-IAC-011 Data sources | Only generic ones for account, Region and partition |
| PC-IAC-016 Secrets | No secret input, value or output |
| PC-IAC-020 Security | Rotating keys, least privilege per role, the single resource `*` recorded as an exception |
| PC-IAC-023 Own service | Only KMS, IAM and VPC filtering resources. The VPC, subnets and endpoints stay in the network module |
| PC-IAC-025 Names | The root passes every final name. The module adds none |
| PC-IAC-026 Sample | `tfvars`, variables, data, locals, then the module call |

## Develop and test

The exact Terraform version lives in `.terraform-version`. Tests run against a mocked provider, so they need no AWS account and spend no credits. They cover the validations, the key policies, the trust policies, every permission statement, the firewall rules and the outputs. The firewall tests run in `tests/firewall.tftest.hcl`.

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
| Firehose access to S3 and to Glue for format conversion | https://docs.aws.amazon.com/firehose/latest/dev/controlling-access.html |
| SNS delivery status logging role | https://docs.aws.amazon.com/sns/latest/dg/topics-attrib-prereq.html |
| End User Messaging SMS role for a CloudWatch Logs event destination | https://docs.aws.amazon.com/sms-voice/latest/userguide/configuration-sets-cloud-watch-creating-role.html |
| SQS, SNS and DynamoDB with customer managed keys | https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-key-management.html, https://docs.aws.amazon.com/sns/latest/dg/sns-key-management.html, https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/encryption.usagenotes.html |
| S3 encryption context and Bucket Keys | https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html |
| Bedrock inference profile permissions | https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-prereq.html |
| KMS prices and deletion | https://aws.amazon.com/kms/pricing/, https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html |
| Default egress removal, exclusive rules, network ACL rules | AWS provider 6.72.0 documentation of `aws_security_group`, `aws_vpc_security_group_rules_exclusive` and `aws_network_acl_rule` |
| Network ACLs are stateless, and 1024 to 65535 covers the ephemeral ports of clients | https://docs.aws.amazon.com/vpc/latest/userguide/custom-network-acl.html |

## Related repositories

| Repository | Role |
|---|---|
| [`aromapacifico-devops-infra`](https://github.com/aromapacifico-devops/aromapacifico-devops-infra) | Roots of each environment, which consume this module |
| [`terraform-aws-module-template`](https://github.com/aromapacifico-devops/terraform-aws-module-template) | Template this repository was generated from |
| [`aromapacifico-devops-docs`](https://github.com/aromapacifico-devops/aromapacifico-devops-docs) | Architecture and design documents |
