resource "aws_vpc" "tf_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "tf_public_subnet" {
  vpc_id                  = aws_vpc.tf_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "tf_igw" {
  vpc_id = aws_vpc.tf_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "tf_public_rt" {
  vpc_id = aws_vpc.tf_vpc.id

  tags = {
    Name = "dev_public_rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.tf_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.tf_igw.id
}

resource "aws_route_table_association" "tf_public_assoc" {
  subnet_id      = aws_subnet.tf_public_subnet.id
  route_table_id = aws_route_table.tf_public_rt.id
}

resource "aws_security_group" "tf_sg" {
  name        = "public_sg"
  description = "public security group"
  vpc_id      = aws_vpc.tf_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] //insert your ip
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "tf_auth" {
  key_name   = "tfkey"
  public_key = file("~/.ssh/tfkey.pub") // file is a tf fn
}

resource "aws_instance" "dev_node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.tf_auth.id
  vpc_security_group_ids = [aws_security_group.tf_sg.id]
  subnet_id              = aws_subnet.tf_public_subnet.id
  user_data              = templatefile("userdata.tpl", {})

  root_block_device {
    volume_size = 8
  }

  tags = {
    Name = "dev_node"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = "~/.ssh/tfkey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }
}
