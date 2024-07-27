Setting up a local stack that emulates AWS services like IAM, Lambda, S3, and RDS can be done using `localstack`. LocalStack is a fully functional local AWS cloud stack that helps you test your cloud infrastructure without needing to connect to AWS.

Here’s a step-by-step guide to set up LocalStack with IAM, Lambda, S3, and RDS:

### Step 1: Install Docker

Ensure Docker is installed on your system. You can download it from [here](https://www.docker.com/get-started).

### Step 2: Install LocalStack

You can run LocalStack using Docker. First, create a `docker-compose.yml` file to define your LocalStack setup.

```yaml
version: '3.8'
services:
  localstack:
    image: localstack/localstack
    ports:
      - "4566:4566"
      - "4571:4571"
    environment:
      - SERVICES=iam,s3,lambda,rds
      - DEBUG=1
      - DATA_DIR=/tmp/localstack/data
    volumes:
      - "./localstack:/tmp/localstack"
```

This configuration will set up LocalStack to emulate IAM, S3, Lambda, and RDS services.

### Step 3: Start LocalStack

Run the following command to start LocalStack using Docker Compose:

```sh
docker-compose up
```

### Step 4: Configure AWS CLI to Use LocalStack

Set up the AWS CLI to use LocalStack endpoints. You can do this by creating a profile in the AWS CLI configuration.

```sh
aws configure --profile localstack
```

For the configuration, use the following values:
- **AWS Access Key ID**: `test`
- **AWS Secret Access Key**: `test`
- **Default region name**: `us-east-1`
- **Default output format**: `json`

Then create a file named `~/.aws/credentials` and add the following lines:

```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

And create a file named `~/.aws/config` and add the following lines:

```ini
[profile localstack]
region = us-east-1
output = json
```

### Step 5: Interact with LocalStack Services

Now you can use AWS CLI or SDKs to interact with LocalStack services. Here are examples for setting up IAM, S3, Lambda, and RDS.

#### a) IAM

Create a new IAM role:

```sh
aws --endpoint-url=http://localhost:4566 iam create-role --role-name lambda-ex --assume-role-policy-document file://trust-policy.json --profile localstack
```

`trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

#### b) S3

Create a new S3 bucket:

```sh
aws --endpoint-url=http://localhost:4566 s3api create-bucket --bucket my-bucket --profile localstack
```

#### c) Lambda

Create a Lambda function. First, create a simple Lambda function (`lambda_function.py`):

```python
def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'body': 'Hello from Lambda!'
    }
```

Create a deployment package:

```sh
zip function.zip lambda_function.py
```

Then, create the Lambda function:

```sh
aws --endpoint-url=http://localhost:4566 lambda create-function --function-name my-function --zip-file fileb://function.zip --handler lambda_function.lambda_handler --runtime python3.8 --role arn:aws:iam::000000000000:role/lambda-ex --profile localstack
```

#### d) RDS

Create a new RDS instance:

```sh
aws --endpoint-url=http://localhost:4566 rds create-db-instance --db-instance-identifier mydb --db-instance-class db.t2.micro --engine postgres --master-username root --master-user-password password --allocated-storage 20 --profile localstack
```

### Summary

This setup allows you to create and interact with IAM, Lambda, S3, and RDS services locally using LocalStack. You can use this local setup for testing and development before deploying your applications to the actual AWS cloud.