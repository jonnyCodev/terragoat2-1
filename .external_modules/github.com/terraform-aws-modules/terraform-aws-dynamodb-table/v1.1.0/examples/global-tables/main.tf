provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  alias  = "euwest2"
  region = "eu-west-2"
}

locals {
  tags = {
    Terraform   = "true"
    Environment = "staging"
  }
}

################################################################################
# Supporting Resources
################################################################################

resource "random_pet" "this" {
  length = 2
}

resource "aws_kms_key" "primary" {
  description = "CMK for primary region"
  tags = merge(local.tags, {
    yor_trace = "2768a849-6df0-4205-b8bc-403063d60723"
  })
}

resource "aws_kms_key" "secondary" {
  provider = aws.euwest2

  description = "CMK for secondary region"
  tags = merge(local.tags, {
    yor_trace = "35a395d1-aace-4504-99b0-f426aae08306"
  })
}

################################################################################
# DynamoDB Global Table
################################################################################

module "dynamodb_table" {
  source = "../../"

  name             = "my-table-${random_pet.this.id}"
  hash_key         = "id"
  range_key        = "title"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  server_side_encryption_enabled     = true
  server_side_encryption_kms_key_arn = aws_kms_key.primary.arn

  attributes = [
    {
      name = "id"
      type = "N"
    },
    {
      name = "title"
      type = "S"
    },
    {
      name = "age"
      type = "N"
    }
  ]

  global_secondary_indexes = [
    {
      name               = "TitleIndex"
      hash_key           = "title"
      range_key          = "age"
      projection_type    = "INCLUDE"
      non_key_attributes = ["id"]
    }
  ]

  replica_regions = [{
    region_name = "eu-west-2"
    kms_key_arn = aws_kms_key.secondary.arn
  }]

  tags = local.tags
}
