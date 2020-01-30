/*
terraform {
  backend "s3" {
    bucket = "z-terraform-up-and-running-state"
    key = "stage/data-stores/myslq/terraform.tfstate"
    region = "us-east-1"

    #locking Table
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
}
*/
resource "aws_db_instance" "example"{
  identifier_prefix = "terraform-up-and-running"
  engine = "mysql"
  allocated_storage = 10
  instance_class   = "db.t2.micro"
  #name = "example_database"
  name = var.db_name
  username = "admin"
  skip_final_snapshot = true

  password = var.db_password
}