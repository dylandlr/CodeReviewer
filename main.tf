# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# VPC and Network Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "code-reviewer-vpc"
  }
}

# Security Groups
resource "aws_security_group" "codecommit_sg" {
  name        = "codecommit-sg"
  description = "Security group for CodeCommit"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_security_group" "codeguru_sg" {
  name        = "codeguru-sg"
  description = "Security group for CodeGuru"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.codecommit_sg.id]
  }
}

# KMS Key for encryption
resource "aws_kms_key" "code_reviewer" {
  description             = "KMS key for code reviewer encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# CodeCommit Repository
resource "aws_codecommit_repository" "code_repo" {
  repository_name = var.repository_name
  description     = "Repository for code review automation"

  tags = {
    Environment = var.environment
  }
}

# IAM Roles and Policies
resource "aws_iam_role" "codepipeline_role" {
  name = "code-reviewer-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "code-reviewer-pipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive",
          "codeguru-reviewer:*",
          "s3:*",
          "kms:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# CodeGuru Reviewer
resource "aws_codeguru_reviewer_repository_association" "example" {
  name = aws_codecommit_repository.code_repo.repository_name
  type = "CodeCommit"
}

# CodePipeline
resource "aws_codepipeline" "code_pipeline" {
  name     = "code-reviewer-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.code_reviewer.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.code_repo.repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "CodeReview"

    action {
      name            = "CodeGuruReview"
      category        = "Test"
      owner          = "AWS"
      provider       = "CodeGuru-Reviewer"
      version        = "1"
      input_artifacts = ["source_output"]

      configuration = {
        RepositoryAssociationArn = aws_codeguru_reviewer_repository_association.example.arn
      }
    }
  }
}

# S3 Bucket for artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = "code-reviewer-artifacts-${var.environment}"
}

resource "aws_s3_bucket_encryption" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.code_reviewer.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

# CloudWatch for monitoring
resource "aws_cloudwatch_log_group" "code_reviewer" {
  name              = "/aws/code-reviewer"
  retention_in_days = 14
}

# Variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "repository_name" {
  description = "Name of the CodeCommit repository"
  type        = string
}

# Outputs
output "repository_clone_url_http" {
  description = "The HTTP clone URL of the repository"
  value       = aws_codecommit_repository.code_repo.clone_url_http
}

output "codeguru_association_arn" {
  description = "The ARN of the CodeGuru reviewer association"
  value       = aws_codeguru_reviewer_repository_association.example.arn
}

output "pipeline_arn" {
  description = "The ARN of the CodePipeline"
  value       = aws_codepipeline.code_pipeline.arn
}