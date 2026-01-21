# 1. VPC 

resource "aws_vpc" "vpc1" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name       = "${var.project_name}-vpc1"
    Managed_by = var.managed_by
  }
}

# 2. IGW
resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "${var.project_name}-igw1"
  }
}

# 3. Public subnet 

resource "aws_subnet" "pub_sub1" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-pub_sub1"
  }
}
resource "aws_subnet" "pub_sub2" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-west-1"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-pub_sub2"
  }
}

# . Private subnet 1
resource "aws_subnet" "pri_sub1" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "${var.project_name}-private_sub1"
  }
}


# 5. Public RT 

resource "aws_route_table" "public_rt1" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
  }

  tags = {
    Name = "${var.project_name}-public_rt1"

  }
}

# 6. Public subnet association

resource "aws_route_table_association" "pub_sub1_rt1" {
  subnet_id      = aws_subnet.pub_sub1.id
  route_table_id = aws_route_table.public_rt1.id
}

resource "aws_route_table_association" "pub_sub1_rt2" {
  subnet_id      = aws_subnet.pub_sub2.id
  route_table_id = aws_route_table.public_rt1.id
}



# 7. Private RT 1
resource "aws_route_table" "pri_rt1" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "${var.project_name}-pri_rt1"
  }
}

# 8. Private subnet association
resource "aws_route_table_association" "pri_sub1_rt1" {
  subnet_id      = aws_subnet.pri_sub1.id
  route_table_id = aws_route_table.pri_rt1.id
}


# 9.ALB security group
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.vpc1.id
  name   = "${var.project_name}-alb-sg"

  ingress {
    from_port   = 80
    to_port     = 80
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

# 10. Security Group 1 
resource "aws_security_group" "sg1" {
  name   = "${var.project_name}-sg1"
  vpc_id = aws_vpc.vpc1.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["155.63.246.10/32"]
  }
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg1"
  }
}


#11.key pair

#resource "aws_key_pair" "demov1" {
# key_name   = "demov1"
# public_key = file("C:\\Users\\lalitsr\\vpc\\demov1.pub")
#}

#12.IAM user
resource "aws_iam_user" "demo_user" {
  name = "${var.project_name}-user"

  tags = {
    Managed_by = var.managed_by
  }
}

#13.IAM policy
resource "aws_iam_policy" "demo_policy" {
  name = "${var.project_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "iam:GetUser",
          "iam:GetPolicy",
          "iam:List*",
          "iam:GetRole",
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}


#14.policy attachment
resource "aws_iam_user_policy_attachment" "demo_attach" {
  user       = aws_iam_user.demo_user.name
  policy_arn = aws_iam_policy.demo_policy.arn
}


# 15. Ec2 - web1(public)
resource "aws_instance" "web1" {
  ami                         = "ami-02dc6e3e481e2bbc5"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.pub_sub1.id
  key_name                    = "demo"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg1.id]

  tags = {
    Name = "${var.project_name}-web1"
  }
}

# 16. Ec2 - web2(private)

resource "aws_instance" "db" {
  ami                    = "ami-02dc6e3e481e2bbc5"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.pri_sub1.id
  key_name               = "demo"
  vpc_security_group_ids = [aws_security_group.sg1.id]

  tags = {
    Name = "${var.project_name}-db"

  }
}

#17.Load Balancer

resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.pub_sub1.id, aws_subnet.pub_sub2.id]
}

#18.Target Group

resource "aws_lb_target_group" "tg" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc1.id

  health_check {
    path = "/"
  }
}

#19.Target Group attachment
resource "aws_lb_target_group_attachment" "web_attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}


#20.Listner

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
# resource "aws_acm_certificate" "cert" {
#   domain_name       = "demol-example.com"
#   validation_method = "DNS"
#   lifecycle {
#     create_before_destroy = true
#   }
# }
# resource "aws_lb_listener" "listener1" {
#   load_balancer_arn = aws_lb.alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
# certificate_arn   = aws_acm_certificate.cert.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.tg.arn
#   }
# }


output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "iam_user_name" {
  value = aws_iam_user.demo_user.name
}


