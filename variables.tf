# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-east-1"
}

variable "cognito_user_pool_name" {
  description = "Nome do pool de usuários do Cognito"
  type        = string
  default     = "mypool"
}