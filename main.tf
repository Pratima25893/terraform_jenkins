provider "aws" {
  region     = var.region
  access_key = "AKIAQZAAT47DQPXV5RW3"
  secret_key = "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"
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc-cidr
  enable_dns_hostnames = true
}

resource "aws_subnet" "subnet-a-public" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet-cidr-a
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "subnet-c-private" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet-cidr-c
  availability_zone = "${var.region}c"
}

resource "aws_route_table" "subnet-route-table-public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "subnet-route-table-private" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NATgw.id
  }
}

resource "aws_route_table_association" "PublicRTassociation-a" {
  subnet_id      = aws_subnet.subnet-a-public.id
  route_table_id = aws_route_table.subnet-route-table-public.id
}


resource "aws_route_table_association" "PrivateRTassociation" {
  subnet_id      = aws_subnet.subnet-c-private.id
  route_table_id = aws_route_table.subnet-route-table-private.id
}

resource "aws_route_table_association" "subnet-a-route-table-association" {
  subnet_id      = aws_subnet.subnet-a-public.id
  route_table_id = aws_route_table.subnet-route-table-public.id
}

resource "aws_route_table_association" "subnet-c-route-table-association" {
  subnet_id      = aws_subnet.subnet-c-private.id
  route_table_id = aws_route_table.subnet-route-table-private.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}


resource "aws_eip" "nateIP" {
  vpc = true
}

resource "aws_nat_gateway" "NATgw" {
  allocation_id = aws_eip.nateIP.id
  subnet_id     = aws_subnet.subnet-a-public.id
}

data "aws_ami" "i" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_instance" "instance" {
  ami                         = data.aws_ami.i.id
  instance_type               = "t2.small"
  vpc_security_group_ids      = [aws_security_group.security-group.id]
  subnet_id                   = aws_subnet.subnet-a-public.id
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/bash
sudo yum update –y
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum upgrade
sudo yum install jenkins java-1.8.0-openjdk-devel -y
sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl status jenkins
#!/bin/bash
sudo yum install python3 -y
sudo yum install epel-release
sudo yum update -y
sudo yum install ansible -y
EOF
}

resource "aws_instance" "instance_priv" {
  ami                         = data.aws_ami.i.id
  instance_type               = "t2.small"
  vpc_security_group_ids      = [aws_security_group.security-group.id]
  subnet_id                   = aws_subnet.subnet-c-private.id
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/bash
sudo yum update –y
sudo yum install -y yum-utils
sudo yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl start docker
sudo usermod -aG docker cloud_user
sudo usermod -aG docker jenkins
sudo systemctl enable --now docker
sudo chmod 666 /var/run/docker.sock

#!/bin/bash 
sudo yum -y java-1.8.0-openjdk-devel 
sudo yum -y install tomcat 
sudo systemctl enable tomcat 
sudo systemctl start tomcat 
echo "welcome to tomcat,Hello World" 
//etc/systemd/system/{{to muser}}.service
EOF
}

resource "aws_security_group" "security-group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
