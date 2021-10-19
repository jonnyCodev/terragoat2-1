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
# Lambda Function with event source mapping
####################################################

module "lambda_function" {
  source = "../../"

  function_name = "${random_pet.this.id}-lambda-event-source-mapping"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "${path.module}/../fixtures/python3.8-app1"

  event_source_mapping = {
    sqs = {
      event_source_arn = aws_sqs_queue.this.arn
    }
    dynamodb = {
      event_source_arn           = aws_dynamodb_table.this.stream_arn
      starting_position          = "LATEST"
      destination_arn_on_failure = aws_sqs_queue.failure.arn
    }
    kinesis = {
      event_source_arn  = aws_kinesis_stream.this.arn
      starting_position = "LATEST"
    }
    mq = {
      event_source_arn = aws_mq_broker.this.arn
      queues           = ["my-queue"]
      source_access_configuration = [
        {
          type = "BASIC_AUTH"
          uri  = aws_secretsmanager_secret.this.arn
        },
        {
          type = "VIRTUAL_HOST"
          uri  = "/"
        }
      ]
    }
  }

  allowed_triggers = {
    sqs = {
      principal  = "sqs.amazonaws.com"
      source_arn = aws_sqs_queue.this.arn
    }
    dynamodb = {
      principal  = "dynamodb.amazonaws.com"
      source_arn = aws_dynamodb_table.this.stream_arn
    }
    kinesis = {
      principal  = "kinesis.amazonaws.com"
      source_arn = aws_kinesis_stream.this.arn
    }
    mq = {
      principal  = "mq.amazonaws.com"
      source_arn = aws_mq_broker.this.arn
    }
  }

  create_current_version_allowed_triggers = false

  attach_network_policy = true

  attach_policy_statements = true
  policy_statements = {
    # Allow failures to be sent to SQS queue
    sqs_failure = {
      effect    = "Allow",
      actions   = ["sqs:SendMessage"],
      resources = [aws_sqs_queue.failure.arn]
    },
    # Execution role permissions to read records from an Amazon MQ broker
    # https://docs.aws.amazon.com/lambda/latest/dg/with-mq.html#events-mq-permissions
    mq_event_source = {
      effect    = "Allow",
      actions   = ["ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeVpcs"],
      resources = ["*"]
    },
    mq_describe_broker = {
      effect    = "Allow",
      actions   = ["mq:DescribeBroker"],
      resources = [aws_mq_broker.this.arn]
    },
    secrets_manager_get_value = {
      effect    = "Allow",
      actions   = ["secretsmanager:GetSecretValue"],
      resources = [aws_secretsmanager_secret.this.arn]
    }
  }

  attach_policies    = true
  number_of_policies = 3

  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaDynamoDBExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaKinesisExecutionRole",
  ]
}

##################
# Extra resources
##################

# Shared resources
resource "random_pet" "this" {
  length = 2
}

resource "random_password" "this" {
  length  = 40
  special = false
}

# SQS
resource "aws_sqs_queue" "this" {
  name = random_pet.this.id
  tags = {
    yor_trace = "1eca8f74-b533-4129-95be-3544dd772da6"
  }
}

resource "aws_sqs_queue" "failure" {
  name = "${random_pet.this.id}-failure"
  tags = {
    yor_trace = "d84f3421-c576-487f-a893-f77dde6ce1ae"
  }
}

# DynamoDB
resource "aws_dynamodb_table" "this" {
  name             = random_pet.this.id
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "UserId"
  range_key        = "GameTitle"
  stream_view_type = "NEW_AND_OLD_IMAGES"
  stream_enabled   = true

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "GameTitle"
    type = "S"
  }
  tags = {
    yor_trace = "9b0cd218-0c55-4756-a638-609d302600c8"
  }
}

# Kinesis
resource "aws_kinesis_stream" "this" {
  name        = random_pet.this.id
  shard_count = 1
  tags = {
    yor_trace = "e90c59f3-c4ec-43d3-a9c3-65a6c3e694f7"
  }
}

# Amazon MQ
data "aws_vpc" "default" {
  default = true
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

resource "aws_mq_broker" "this" {
  broker_name        = random_pet.this.id
  engine_type        = "RabbitMQ"
  engine_version     = "3.8.11"
  host_instance_type = "mq.t3.micro"
  security_groups    = [data.aws_security_group.default.id]

  user {
    username = random_pet.this.id
    password = random_password.this.result
  }
  tags = {
    yor_trace = "a09d3d0b-a7bf-486a-b0e8-f311b9d0cc76"
  }
}

resource "aws_secretsmanager_secret" "this" {
  name = "${random_pet.this.id}-mq-credentials"
  tags = {
    yor_trace = "36ee52b9-a46c-4bdf-a530-6fa071ea01d7"
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    username = random_pet.this.id
    password = random_password.this.result
  })
}
