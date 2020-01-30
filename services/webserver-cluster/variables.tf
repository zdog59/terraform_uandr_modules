variable "cluster_name"{
    description = "The name to use for all the cluster resources"
    type = string
}

variable "db_remote_state_bucket"{
    description = "The name of the s3's bucket for the remote state"
    type = string
}

variable "db_remote_state_key" {
    description = "The path for database's the remote state in s3"
    type = string
}

variable "instance_type" {
    description = "The type of EC2 Instances to run (e.g. t2.micro)"
    type = string
    default = "t2.micro"
}

variable "min_size" {
    description = "The minimum number of EC2 Instances in the ASG"
    type = number
}

variable "max_size" {
    description = "The maximum number of EC2 Instances in the ASG"
    type = number
}

variable "server_port" {
    description = "The port for http connection"
    type = number
    default = 8080
}




