provider "aws" {
  region = "eu-west-1"

  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

resource "random_pet" "this" {
  length = 2
}

module "lambda_function" {
  source = "../../"

  function_name = "${random_pet.this.id}-lambda-async"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  architectures = ["arm64"]

  source_path = "${path.module}/../fixtures/python3.8-app1"

  create_async_event_config = true
  attach_async_event_policy = true

  maximum_event_age_in_seconds = 100
  maximum_retry_attempts       = 1

  destination_on_failure = aws_sns_topic.async.arn
  destination_on_success = aws_sqs_queue.async.arn
}

resource "aws_sns_topic" "async" {
  name_prefix = random_pet.this.id
  tags = {
    yor_trace = "86656024-4745-4bae-bf6f-ecc89eb2e85f"
  }
}

resource "aws_sqs_queue" "async" {
  name_prefix = random_pet.this.id
  tags = {
    yor_trace = "ae66f2f1-759c-4f3e-8f49-3b022849e4a4"
  }
}
