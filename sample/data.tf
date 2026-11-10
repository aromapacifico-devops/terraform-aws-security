# Data sources of the sample. They find the IDs the module receives, so that the values file holds none.
data "aws_caller_identity" "current" {
  provider = aws.principal
}

data "aws_region" "current" {
  provider = aws.principal
}

data "aws_partition" "current" {
  provider = aws.principal
}
