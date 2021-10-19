provider "aws" {
  region = "eu-west-1"

  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

####################################################
# Lambda Function (building locally, storing on S3,
# set allowed triggers, set policies)
####################################################

module "lambda_function" {
  source = "../../"

  function_name = "${random_pet.this.id}-lambda1"
  description   = "My awesome lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  architectures = ["x86_64"]
  publish       = true

  source_path = "${path.module}/../fixtures/python3.8-app1"

  store_on_s3 = true
  s3_bucket   = module.s3_bucket.s3_bucket_id
  s3_prefix   = "lambda-builds/"

  artifacts_dir = "${path.root}/.terraform/lambda-builds/"

  layers = [
    module.lambda_layer_local.lambda_layer_arn,
    module.lambda_layer_s3.lambda_layer_arn,
  ]

  environment_variables = {
    Hello      = "World"
    Serverless = "Terraform"
  }

  role_path   = "/tf-managed/"
  policy_path = "/tf-managed/"

  attach_dead_letter_policy = true
  dead_letter_target_arn    = aws_sqs_queue.dlq.arn

  allowed_triggers = {
    APIGatewayAny = {
      service    = "apigateway"
      source_arn = "arn:aws:execute-api:eu-west-1:135367859851:aqnku8akd0/*/*/*"
    },
    APIGatewayDevPost = {
      service    = "apigateway"
      source_arn = "arn:aws:execute-api:eu-west-1:135367859851:aqnku8akd0/dev/POST/*"
    },
    OneRule = {
      principal  = "events.amazonaws.com"
      source_arn = "arn:aws:events:eu-west-1:135367859851:rule/RunDaily"
    }
  }

  ######################
  # Additional policies
  ######################

  assume_role_policy_statements = {
    account_root = {
      effect  = "Allow",
      actions = ["sts:AssumeRole"],
      principals = {
        account_principal = {
          type        = "AWS",
          identifiers = ["arn:aws:iam::135367859851:root"]
        }
      }
      condition = {
        stringequals_condition = {
          test     = "StringEquals"
          variable = "sts:ExternalId"
          values   = ["12345"]
        }
      }
    }
  }

  attach_policy_json = true
  policy_json        = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "xray:GetSamplingStatisticSummaries"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF

  attach_policy_jsons = true
  policy_jsons = [<<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "xray:*"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF
  ]
  number_of_policy_jsons = 1

  attach_policy = true
  policy        = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"

  attach_policies    = true
  policies           = ["arn:aws:iam::aws:policy/AWSXrayReadOnlyAccess"]
  number_of_policies = 1

  attach_policy_statements = true
  policy_statements = {
    dynamodb = {
      effect    = "Allow",
      actions   = ["dynamodb:BatchWriteItem"],
      resources = ["arn:aws:dynamodb:eu-west-1:052212379155:table/Test"]
    },
    s3_read = {
      effect    = "Deny",
      actions   = ["s3:HeadObject", "s3:GetObject"],
      resources = ["arn:aws:s3:::my-bucket/*"]
    }
  }

  ###########################
  # END: Additional policies
  ###########################

  tags = {
    Module = "lambda1"
  }
}

##########################################################
# Lambda Function (deploying existing package from local)
##########################################################

module "lambda_function_existing_package_local" {
  source = "../../"

  function_name = "${random_pet.this.id}-lambda-existing-package-local"
  description   = "My awesome lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  publish       = true

  create_package         = false
  local_existing_package = "${path.module}/../fixtures/python3.8-zip/existing_package.zip"
  #  s3_existing_package = {
  #    bucket = "humane-bear-bucket"
  #    key = "builds/506df8bef5a4fb01883cce3673c9ff0ed88fb52e8583410e0cca7980a72211a0.zip"
  #    version_id = null
  #  }

  layers = [
    module.lambda_layer_local.lambda_layer_arn,
    module.lambda_layer_s3.lambda_layer_arn,
  ]
}

#################################
# Lambda Layer (storing locally)
#################################

module "lambda_layer_local" {
  source = "../../"

  create_layer = true

  layer_name               = "${random_pet.this.id}-layer-local"
  description              = "My amazing lambda layer (deployed from local)"
  compatible_runtimes      = ["python3.8"]
  compatible_architectures = ["arm64"]

  source_path = "${path.module}/../fixtures/python3.8-app1"
}

####################################################
# Lambda Layer with package deploying externally
# (e.g., using separate CI/CD pipeline)
####################################################

module "lambda_layer_with_package_deploying_externally" {
  source = "../../"

  create_layer = true

  layer_name          = "${random_pet.this.id}-layer-local"
  description         = "My amazing lambda layer (deployed from local)"
  compatible_runtimes = ["python3.8"]

  create_package         = false
  local_existing_package = "../fixtures/python3.8-zip/existing_package.zip"

  ignore_source_code_hash = true
}

###############################
# Lambda Layer (storing on S3)
###############################

module "lambda_layer_s3" {
  source = "../../"

  create_layer = true

  layer_name          = "${random_pet.this.id}-layer-s3"
  description         = "My amazing lambda layer (deployed from S3)"
  compatible_runtimes = ["python3.8"]

  source_path = "${path.module}/../fixtures/python3.8-app1"

  store_on_s3 = true
  s3_bucket   = module.s3_bucket.s3_bucket_id
}

##############
# Lambda@Edge
##############

module "lambda_at_edge" {
  source = "../../"

  lambda_at_edge = true

  function_name = "${random_pet.this.id}-lambda-at-edge"
  description   = "My awesome lambda@edge function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "${path.module}/../fixtures/python3.8-app1"
  hash_extra  = "this string should be included in hash function to produce different filename for the same source" # this is also a build trigger if this changes

  tags = {
    Module = "lambda-at-edge"
  }
}

###############################################
# Lambda Function with provisioned concurrency
###############################################

module "lambda_with_provisioned_concurrency" {
  source = "../../"

  function_name = "${random_pet.this.id}-lambda-provisioned"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "${path.module}/../fixtures/python3.8-app1"
  publish     = true

  hash_extra = "hash-extra-lambda-provisioned"

  provisioned_concurrent_executions = -1 # 2
}

###############################################
# Lambda Function with mixed trusted entities
###############################################

module "lambda_with_mixed_trusted_entities" {
  source = "../../"

  function_name = "${random_pet.this.id}-lambda-mixed-trusted-entities"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "${path.module}/../fixtures/python3.8-app1"

  trusted_entities = [
    "appsync.amazonaws.com",
    {
      type = "AWS",
      identifiers = [
        "arn:aws:iam::307990089504:root",
      ]
    },
    {
      type = "Service",
      identifiers = [
        "codedeploy.amazonaws.com",
        "ecs.amazonaws.com"
      ]
    }
  ]
}

##############################
# Lambda Functions + for_each
##############################

module "lambda_function_for_each" {
  source = "../../"

  for_each = toset(["dev", "staging", "prod"])

  function_name = "my-${each.value}"
  description   = "My awesome lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  publish       = true

  create_package         = false
  local_existing_package = "${path.module}/../fixtures/python3.8-zip/existing_package.zip"
}

####################################################
# Lambda Function with package deploying externally
# (e.g., using separate CI/CD pipeline)
####################################################

module "lambda_function_with_package_deploying_externally" {
  source = "../../"

  function_name = "${random_pet.this.id}-lambda-with-package-deploying-externally"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  create_package         = false
  local_existing_package = "../fixtures/python3.8-zip/existing_package.zip"

  ignore_source_code_hash = true
}

###########
# Disabled
###########

module "disabled_lambda" {
  source = "../../"

  create = false
}

##################
# Extra resources
##################

resource "random_pet" "this" {
  length = 2
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket        = "${random_pet.this.id}-bucket"
  force_destroy = true
}

resource "aws_sqs_queue" "dlq" {
  name = random_pet.this.id
  tags = {
    yor_trace = "9ca07530-414a-44a3-bf44-bac11e314466"
  }
}
