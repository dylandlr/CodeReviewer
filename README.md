# CodeReviewer
AWS-powered Code Review Application

# AWS Environment Implementation Guide

## 1. VPC Setup

```bash
# Create VPC
aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=CodeReviewVPC}]'

# Create Private Subnet
aws ec2 create-subnet \
    --vpc-id <vpc-id> \
    --cidr-block 10.0.1.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PrivateSubnet}]'

# Create necessary VPC Endpoints
aws ec2 create-vpc-endpoint \
    --vpc-id <vpc-id> \
    --vpc-endpoint-type Interface \
    --service-name com.amazonaws.<region>.codecommit \
    --subnet-ids <subnet-id>
```

## 2. CodeCommit Repository Setup

```bash
# Create CodeCommit repository
aws codecommit create-repository \
    --repository-name code-review-repo \
    --repository-description "AI-Powered Code Review Repository"

# Configure repository notifications
aws codecommit create-repository-trigger \
    --repository-name code-review-repo \
    --trigger-name pipeline-trigger \
    --branches main \
    --events all \
    --destination-arn <sns-topic-arn>
```

## 3. CodeGuru Setup

```bash
# Associate repository with CodeGuru Reviewer
aws codeguru-reviewer associate-repository \
    --name code-review-repo \
    --type CodeCommit \
    --owner <aws-account-id> \
    --bucket-name <s3-bucket-name>

# Enable CodeGuru Profiler
aws codeguru-profiler create-profiling-group \
    --profiling-group-name code-review-profiler \
    --compute-platform Default
```

## 4. CodePipeline Setup

```bash
# Create S3 bucket for artifacts
aws s3 mb s3://<unique-bucket-name>-artifacts

# Create CodePipeline
aws codepipeline create-pipeline \
    --pipeline-name code-review-pipeline \
    --pipeline-config file://pipeline-config.json

# Pipeline configuration (pipeline-config.json)
{
    "pipeline": {
        "name": "code-review-pipeline",
        "roleArn": "<pipeline-role-arn>",
        "artifactStore": {
            "type": "S3",
            "location": "<artifact-bucket-name>"
        },
        "stages": [
            {
                "name": "Source",
                "actions": [
                    {
                        "name": "Source",
                        "actionTypeId": {
                            "category": "Source",
                            "owner": "AWS",
                            "provider": "CodeCommit",
                            "version": "1"
                        },
                        "configuration": {
                            "RepositoryName": "code-review-repo",
                            "BranchName": "main"
                        }
                    }
                ]
            },
            {
                "name": "CodeReview",
                "actions": [
                    {
                        "name": "CodeGuruReview",
                        "actionTypeId": {
                            "category": "Test",
                            "owner": "AWS",
                            "provider": "CodeGuru-Reviewer",
                            "version": "1"
                        }
                    }
                ]
            }
        ]
    }
}
```

## 5. Monitoring Setup

```bash
# Create CloudWatch Log Group
aws logs create-log-group \
    --log-group-name /aws/codereview

# Create CloudWatch Metrics
aws cloudwatch put-metric-alarm \
    --alarm-name pipeline-failure \
    --alarm-description "Alert on pipeline failure" \
    --metric-name FailedPipeline \
    --namespace AWS/CodePipeline \
    --statistic Average \
    --period 300 \
    --threshold 1 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1

# Enable VPC Flow Logs
aws ec2 create-flow-logs \
    --resource-type VPC \
    --resource-ids <vpc-id> \
    --traffic-type ALL \
    --log-group-name /aws/vpc/flow-logs
```

## 6. Initial Security Configuration

```bash
# Create KMS Key
aws kms create-key \
    --description "Key for code review platform"

# Create security group
aws ec2 create-security-group \
    --group-name CodeReviewSG \
    --description "Security group for code review services" \
    --vpc-id <vpc-id>

# Configure security group rules
aws ec2 authorize-security-group-ingress \
    --group-id <security-group-id> \
    --protocol tcp \
    --port 443 \
    --cidr 10.0.0.0/16
```

## Verification Steps

1. VPC Setup Verification:
```bash
aws ec2 describe-vpcs --vpc-ids <vpc-id>
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=<vpc-id>
```

2. Repository Verification:
```bash
aws codecommit get-repository --repository-name code-review-repo
```

3. CodeGuru Verification:
```bash
aws codeguru-reviewer list-repository-associations
aws codeguru-profiler list-profiling-groups
```

4. Pipeline Verification:
```bash
aws codepipeline get-pipeline --name code-review-pipeline
```

## Important Notes:

1. Replace all placeholders (<vpc-id>, <region>, etc.) with actual values
2. Run commands in specified order due to dependencies
3. Verify each step before proceeding to next
4. Keep track of created resource ARNs for IAM policy configuration

Next steps will involve:
- IAM role and policy creation
- Detailed security group configurations
- CodeGuru reviewer configuration
- Pipeline customization
