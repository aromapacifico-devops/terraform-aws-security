# Infrastructure code exceptions

A finding of the automated checks is accepted only through a row in this table, added in its own reviewed pull request. Each row states why the finding is acceptable and the condition that ends the exception.

| Rule | Path | Resource | Reason | Expires when |
|---|---|---|---|---|
| PC-IAC-020, least privilege without `*` | `locals.tf` | Statement `DetectLabels` of the focus confirmation function role | Rekognition `DetectLabels` has no resource type in the AWS service authorization reference, so IAM accepts only the resource `*` for it. The statement holds that single action | AWS adds a resource type to `DetectLabels` |
| PC-IAC-010, `prevent_destroy` on critical resources | `main.tf` | `aws_kms_key.keys` | Every environment of the demonstration is destroyed each night and rebuilt. The deletion window keeps a destroyed key recoverable for 7 days in development and test and 30 days in production | Environments stop being destroyed each night, as in a pilot |
