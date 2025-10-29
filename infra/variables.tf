variable "aws_region" {
  type    = string
  default = "eu-west-2" # London
}

variable "project" {
  type    = string
  default = "daily-task-scheduler"
}

variable "email" {
  type        = string
  description = "SNS email subscription for notifications"
}