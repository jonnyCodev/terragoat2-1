
module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "my-lambda1"
  description   = "My awesome lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "../src/lambda-function1"

  tags = {
    Name      = "my-lambda1"
    yor_trace = "a7ef4fea-f47a-4391-86e2-3bc522616005"
  }
}
