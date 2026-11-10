# Changelog

## [Unreleased]

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
