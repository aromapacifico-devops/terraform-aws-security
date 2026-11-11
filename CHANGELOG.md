# Changelog

## [Unreleased]

### Added

- Purpose `focus_delivery`, the role the focus rule assumes to put each published flight record on the work queue of the function. It trusts EventBridge from this account and the named rule only, sends to that queue and uses the data key through SQS.
- Inputs `event_bus_arns` and output `focus_delivery_role_arn`.

### Changed

- The focus confirmation function role consumes its work queue, reads exact object versions, removes object versions and puts `inference.completed` events on the platform bus. It no longer reads the latest version of an object.
- The focus confirmation function role uses the data key through SQS for decrypt only.
- `roles` requires the purpose `focus_delivery`, and `focus_function` requires `queue_arns` and `event_bus_arns`.

### Removed

- `dead_letter_queue_arns` and the send permission of the focus role on its dead letter queue, since SQS redrives exhausted messages by itself.

## [0.5.0]

### Added

- Optional input `firewall` with the permanent cloud firewall rules of box C06. One security group per interface endpoint admits TCP 443 from each center range and holds no egress rule, and the module owns the full rule set of each group. A network ACL on the ingress and application subnets admits TCP 443 from the centers and lets the responses out, and a second ACL closes the data, object storage, administration and public query subnets.
- Output `endpoint_security_group_ids` for the interface endpoints of the network module.

## [0.4.0]

### Added

- Roles of alert delivery. The delivery status function writes the push and SMS status of each alert, the delivery check function checks each alert after 5 minutes and sends the urgent SMS, and two service roles let SNS and End User Messaging SMS write their status logs.
- The ingestion function role reads the farm table, updates alert state and delivery fields through conditional updates, and sends a check message to the delivery check queue.
- The Firehose delivery role reads the archive schema in the Glue catalog, which Parquet conversion needs.
- Inputs `push_application_arns`, `send_queue_arns`, `glue_table_arns` and `sms_resource_arns`, and four role ARN outputs.

### Changed

- The ingestion function role publishes to the phone endpoints of the push platform applications in place of a topic, and `topic_arns` is removed. Its data key use through SNS goes with it.
- `roles` requires the purposes `delivery_status_function`, `delivery_check_function`, `push_status_logs` and `sms_status_logs`, and `firehose_delivery` requires `glue_table_arns`.

## [0.3.0]

### Added

- The focus confirmation function role moves an object with a person to the restricted prefix. It may put objects only there and delete objects only in its own prefix, and it may generate data keys with the objects key through S3.

### Changed

- The focus confirmation function role requires `restricted_prefix`, which may not contain the focus prefix or sit inside it.

## [0.2.0]

### Added

- Data and objects KMS keys with aliases, yearly rotation, an explicit key policy and the deletion window from the input.
- Ingestion function, IoT rule, Firehose delivery and focus confirmation function roles, each trusted only by its service.
- One least-privilege inline policy per role, managed exclusively, with key use limited to named services.
- Inputs `keys` and `roles` with validations, and the six key and role ARN outputs.
- Tests against a mocked provider and a complete `sample/`.

The endpoint security groups and their inputs arrive in a later minor release.
