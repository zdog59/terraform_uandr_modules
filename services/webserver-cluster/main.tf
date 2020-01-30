
data "terraform_remote_state" "db"{
  backend  = "s3"

  config = {
    #bucket = "z-terraform-up-and-running-state"
    bucket = var.db_remote_state_bucket
    #key = "stage/data-stores/myslq/terraform.tfstate"
    key = var.db_remote_state_key
    region = "us-east-1"
  }
}

data "template_file" "user_data"{
  #template = file("user-data.sh")
   template = file("${path.module}/user-data.sh")


  vars = {
    server_port = var.server_port
    #db_address = data.terraform_remote_state.db.outputs.address
    db_address = data.terraform_remote_state.db.outputs.db_addr
    #db_port = data.terraform_remote_state.db.outputs.port
    db_port = data.terraform_remote_state.db.outputs.db_port
  }
}

#arguments are filters.  for below default = true to look up the default vpc
data "aws_vpc" "default"{
    default = true
}
#query provider to return the subnet_ids for the default vpc by id
data "aws_subnet_ids" "default"{
    vpc_id = data.aws_vpc.default.id
}

locals {
    http_port = 80
    any_port = 0
    any_protocol = "-1"
    tcp_protocol = "tcp"
    all_ips = [ "0.0.0.0/0" ]
}

resource "aws_launch_configuration" "example" {
    #ami =  "ami-062f7200baf2fa504"
    image_id = "ami-04b9e92b5572fa0d1"
    #instance_type = "t2.micro"
    instance_type = var.instance_type
    security_groups = [aws_security_group.instance.id]
    user_data = data.template_file.user_data.rendered
    /*
    user_data = <<-EOF
            #!/bin/bash
            echo "Hello, World!" > index.html
            nohup busybox httpd -f -p ${var.server_port} &
            EOF
    */
    # Required when using a launch configuration with an autoscaling group
    #https://www.terraform.io/docs/providers/aws/r/launch_configuration.html

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "example"{
    launch_configuration = aws_launch_configuration.example.name
    vpc_zone_identifier = data.aws_subnet_ids.default.ids

    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"


    #min_size = 2
    min_size = var.min_size
    #max_size = 10
    max_size = var.max_size

    tag {
        key = "Name"
        #value = "terraform-asg-example"
        value = var.cluster_name
        propagate_at_launch = true
    }

}

resource "aws_security_group" "instance"{
    #name = "terraform-example-instance"
    name = "${var.cluster_name}-instance"
    ingress {
        from_port = var.server_port
        to_port = var.server_port
        #protocol = "tcp"
        protocol = local.tcp_protocol
        #cidr_blocks = [ "0.0.0.0/0" ]
        cidr_blocks = local.all_ips
    }
}

resource "aws_lb" "example"{
    #name = "terraform-asg-example"
    name = var.cluster_name
    load_balancer_type = "application"
    subnets =   data.aws_subnet_ids.default.ids
    security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http"{
    load_balancer_arn = aws_lb.example.arn
    #port = 80
    port = local.http_port
    protocol = "HTTP"

    default_action {
        type = "fixed-response"

        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code = "404"
        }
    }
}

resource "aws_security_group" "alb"{
    #name = "terraform-example-alb"
    name = "${var.cluster_name}-alb"
    /*
    #Allow incoming HTTP
    ingress {
        #from_port = 80
        from_port = local.http_port
        #protocol = "TCP"
        protocol = local.tcp_protocol
        #to_port = 80
        to_port = local.http_port
        #cidr_blocks = ["0.0.0.0/0"]
        cidr_blocks = local.all_ips
    }

    #Allow all outbound requests
    egress {
        #from_port = 0
        from_port = local.any_port
        #protocol = "-1"
        protocol = local.any_protocol
        #to_port = 0
        to_port = local.any_port
        #cidr_blocks = ["0.0.0.0/0"]
        cidr_blocks = local.all_ips
    }
    */
}

resource "aws_security_group_rule" "ingress"{
    type = "ingress"
    security_group_id = aws_security_group.alb.id

    from_port = local.http_port
    protocol = local.tcp_protocol
    to_port = local.http_port
    cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "egress"{
    type = "egress"
    security_group_id = aws_security_group.alb.id
    from_port = local.any_port
    protocol = local.any_protocol
    to_port = local.any_port
    cidr_blocks = local.all_ips

}

resource "aws_lb_target_group" "asg"{
    #name = "terraform-asg-example"
    name = var.cluster_name
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_subnet_ids.default.id

    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}

resource "aws_alb_listener_rule" "asg"{
    listener_arn = aws_lb_listener.http.arn
    priority = "100"

    condition {
        field = "path-pattern"
        values = ["*"]
    }

    action{
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }
}
/*
output "alb_dns_name" {
    value = aws_lb.example.dns_name
    description = "The domain name of the load balancer."
}
*/


