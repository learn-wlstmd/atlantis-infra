resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "atlantis-vpc"
  }
}

# Public

## Internet Gateway
resource"aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "atlantis-igw"
  }
}

## Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "atlantis-public-rt"
  }
}
 
resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main.id
}

## Public Subnet
resource "aws_subnet" "public_a" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "atlantis-public-subnet-a"
  }
}

## Attach Public Subnet in Route Table
resource "aws_route_table_association" "public_a" {
  subnet_id = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}


# EC2

# EBS Encryption
resource "aws_ebs_encryption_by_default" "ebs" {
  enabled = true
}

## Keypair
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "keypair" {
  key_name = "atlantis"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "local_file" "keypair" {
  content = tls_private_key.rsa.private_key_pem
  filename = "./atlantis.pem"
}

data "aws_ssm_parameter" "latest_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

## Public EC2
resource "aws_instance" "atlantis_instance" {
  ami = data.aws_ssm_parameter.latest_ami.value
  subnet_id = aws_subnet.public_a.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.keypair.key_name
  vpc_security_group_ids = [aws_security_group.atlantis_instance.id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.atlantis_instance.name
  user_data = <<-EOF
  #!/bin/bash
  yum update -y
  yum install -y httpd
  service httpd start
  echo $(hostname -I) > /var/www/html/ip.html
  date=$(TZ=Asia/Seoul date +"%Y-%m-%d:%H:%M")
  echo $date > /var/www/html/date.html
  echo "WEB Page!" > /var/www/html/index.html
  EOF
  tags = {
    Name = "atlantis-instance"
  }
}

## Public Security Group
resource "aws_security_group" "atlantis_instance" {
  name = "atlantis-instance-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = "22"
    to_port = "22"
  }

  ingress {
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = "80"
    to_port = "80"
  }

  egress {
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = "0"
    to_port = "0"
  }
 
  tags = {
    Name = "atlantis-instance-sg"
  }
}

## IAM
resource "aws_iam_role" "atlantis_instance" {
  name = "atlantis-instance-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_iam_instance_profile" "atlantis_instance" {
  name = "atlantis-instance-role"
  role = aws_iam_role.atlantis_instance.name
}

# OutPut

## VPC
output "aws_vpc" {
  value = aws_vpc.main.id
}

## Public Subnet
output "public_a" {
  value = aws_subnet.public_a.id
}

output "atlantis_instance" {
  value = aws_instance.atlantis_instance.id
}

output "atlantis_instance-sg" {
  value = aws_security_group.atlantis_instance.id
}