resource "aws_security_group" "sg" {
  description = "Security Group for Aurora Cluster Bastion Host"
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow egress communication"
    from_port   = "0"
    protocol    = "-1"
    self        = "false"
    to_port     = "0"
  }
  ingress {
    cidr_blocks = ["10.44.34.0/24", "10.44.41.0/24"]
    description = "Allow SSH access from Fyde proxy"
    from_port   = "22"
    protocol    = "tcp"
    self        = "false"
    to_port     = "22"
  }
  ingress {
    description = "Self Reference"
    from_port   = "0"
    protocol    = "-1"
    self        = "true"
    to_port     = "0"
  }
  name = "bc-aurora-cluster-bastion-sg"
  tags = {
    Name      = "bc-aurora-cluster-bastion-sg-BastionSecurityGroup"
    yor_trace = "b4b14a68-a613-4f0a-bd32-54f82a9568e8"
  }
  vpc_id = "vpc-0e095b1b964f8765a"
}
