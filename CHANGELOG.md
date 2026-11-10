# Changelog

## [Unreleased]

## [0.2.0]

### Added

- Data and objects KMS keys with aliases, yearly rotation, an explicit key policy and the deletion window from the input.
- Ingestion function, IoT rule, Firehose delivery and focus confirmation function roles, each trusted only by its service.
- One least-privilege inline policy per role, managed exclusively, with key use limited to named services.
- Inputs `keys` and `roles` with validations, and the six key and role ARN outputs.
- Tests against a mocked provider and a complete `sample/`.

The endpoint security groups and their inputs arrive in a later minor release.
