data aws_ssm_parameter amzn2_ami {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}
data "aws_availability_zones" "available" {
  state = "available"
}

provider "aws" {}

variable "locust_dashboard_client_ip" {
  default = "xxx.xxx.xxx.xxx/xx"
}

variable "locust_instance_type" {
  default = {
    master = "c5.xlarge"
    worker = "c5.xlarge"
  }
}

resource "aws_vpc" "locust-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "locust-vpc"
    }
}

resource "aws_internet_gateway" "locust-igw" {
    vpc_id = aws_vpc.locust-vpc.id
    tags = {
        Name = "locust-igw"
    }
}

resource "aws_subnet" "locust-master-subnet" {
    cidr_block = "10.0.0.0/23"
    vpc_id = aws_vpc.locust-vpc.id
    map_public_ip_on_launch = true
    tags = {
        Name = "locust-master-subnet"
    }
}
resource "aws_subnet" "locust-worker-subnet-0" {
    cidr_block = "10.0.2.0/23"
    vpc_id = aws_vpc.locust-vpc.id
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = true
    tags = {
        Name = "locust-worker-subnet-0"
    }
}
resource "aws_subnet" "locust-worker-subnet-1" {
    cidr_block = "10.0.4.0/23"
    vpc_id = aws_vpc.locust-vpc.id
    availability_zone = data.aws_availability_zones.available.names[1]
    map_public_ip_on_launch = true
    tags = {
        Name = "locust-worker-subnet-1"
    }
}
resource "aws_subnet" "locust-worker-subnet-2" {
    cidr_block = "10.0.6.0/23"
    vpc_id = aws_vpc.locust-vpc.id
    availability_zone = data.aws_availability_zones.available.names[2]
    map_public_ip_on_launch = true
    tags = {
        Name = "locust-worker-subnet-2"
    }
}

resource "aws_route_table" "locust-rt" {
    vpc_id = aws_vpc.locust-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.locust-igw.id
    }
    tags = {
        Name = "locust-rt"
    }
}

resource "aws_route_table_association" "locust-master-subnet" {
  subnet_id = aws_subnet.locust-master-subnet.id
  route_table_id = aws_route_table.locust-rt.id
}
resource "aws_route_table_association" "locust-worker-subnet-0" {
  subnet_id = aws_subnet.locust-worker-subnet-0.id
  route_table_id = aws_route_table.locust-rt.id
}
resource "aws_route_table_association" "locust-worker-subnet-1" {
  subnet_id = aws_subnet.locust-worker-subnet-1.id
  route_table_id = aws_route_table.locust-rt.id
}
resource "aws_route_table_association" "locust-worker-subnet-2" {
  subnet_id = aws_subnet.locust-worker-subnet-2.id
  route_table_id = aws_route_table.locust-rt.id
}


resource "aws_security_group" "locust-master" {
    vpc_id = aws_vpc.locust-vpc.id
    name = "locust-master"
    description = "for locust master"
    tags = {
        Name = "locust-master"
    }
    ingress {
        from_port = 8089
        to_port = 8089
        protocol = "tcp"
        cidr_blocks = [
            var.locust_dashboard_client_ip
        ]
    }
    ingress {
        from_port = 5557
        to_port = 5557
        protocol = "tcp"
        security_groups = [
            "${aws_security_group.locust-worker.id}"
        ]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = [
            "0.0.0.0/0"
        ]
    }
}
resource "aws_security_group" "locust-worker" {
    vpc_id = aws_vpc.locust-vpc.id
    name = "locust-worker"
    description = "for locust worker"
    tags = {
        Name = "locust-worker"
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = [
          "0.0.0.0/0"
        ]
    }
}

data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = [ "sts:AssumeRole" ]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_instance_profile" "locust-master-role" {
    name = "locust-master-role"
    role = aws_iam_role.locust-master-role.name
}
resource "aws_iam_role" "locust-master-role" {
    name = "locust-master-role"
    path = "/"
    assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}
resource "aws_iam_role_policy_attachment" "ssm-master" {
    role = aws_iam_role.locust-master-role.id
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_instance_profile" "locust-worker-role" {
    name = "locust-worker-role"
    role = aws_iam_role.locust-worker-role.name
}
resource "aws_iam_role" "locust-worker-role" {
    name = "locust-worker-role"
    path = "/"
    assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}
resource "aws_iam_role_policy_attachment" "ssm-worker" {
    role = aws_iam_role.locust-worker-role.id
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_instance" "locust-master" {
    ami = data.aws_ssm_parameter.amzn2_ami.value
    instance_type = var.locust_instance_type.master
    key_name = "locust-key"
    subnet_id = aws_subnet.locust-master-subnet.id
    security_groups = [
        "${aws_security_group.locust-master.id}"
    ]
    disable_api_termination = false
    user_data = file("userdata.sh")
    tags = {
        Name = "locust-master"
    }
    iam_instance_profile = "locust-master-role"
    root_block_device {
        volume_type = "gp2"
        volume_size = 50
    }
}

resource "aws_launch_template" "locust-worker" {
  name = "locust-worker"
  image_id = data.aws_ssm_parameter.amzn2_ami.value
  instance_type = var.locust_instance_type.worker
  key_name = "locust-key"
    vpc_security_group_ids = [
        "${aws_security_group.locust-worker.id}"
    ]
  iam_instance_profile {
    name = "locust-worker-role"
  }
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
    }
  }
  disable_api_termination = true
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "locust-worker"
    }
  }
  user_data = base64encode(file("userdata.sh"))
}


resource "aws_autoscaling_group" "locust-worker" {
  name                      = "locust-worker"
  max_size                  = 6
  min_size                  = 3
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 6
  force_delete              = true
  launch_template {
    id      = aws_launch_template.locust-worker.id
    version = "$Latest"
  }
  vpc_zone_identifier       = [
      aws_subnet.locust-worker-subnet-0.id,
      aws_subnet.locust-worker-subnet-1.id,
      aws_subnet.locust-worker-subnet-2.id
  ]

  tag {
    key                 = "foo"
    value               = "bar"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "Name"
    value               = "locust-worker"
    propagate_at_launch = false
  }
}

resource "aws_ssm_document" "locust-master-command" {
  name          = "locust-master-command"
  document_type = "Command"

  content = <<DOC
  {
    "schemaVersion": "1.2",
    "description": "Locust master start",
    "parameters": {

    },
    "runtimeConfig": {
      "aws:runShellScript": {
        "properties": [
          {
            "id": "0.aws:runShellScript",
            "runCommand": [
              "locust -f /root/locustfile.py --master"
            ]
          }
        ]
      }
    }
  }
DOC
}

resource "aws_ssm_document" "locust-worker-command" {
  name          = "locust-worker-command"
  document_type = "Command"

  content = <<DOC
  {
    "schemaVersion": "1.2",
    "description": "Locust worker start",
    "parameters": {

    },
    "runtimeConfig": {
      "aws:runShellScript": {
        "properties": [
          {
            "id": "0.aws:runShellScript",
            "runCommand": [
              "locust -f /root/locustfile.py --worker --master-host=${aws_instance.locust-master.private_ip}"
            ]
          }
        ]
      }
    }
  }
DOC
}

output "Locust_Dashboard" {
  value = "http://${aws_instance.locust-master.public_ip}:8089"
}