# AWS AMI Data Query for CentOS-8-DevOps-Practice
data "aws_ami" "ami" {
  owners      = ["973714476881"]
  most_recent = true
  name_regex  = "Centos-8-DevOps-Practice"
}