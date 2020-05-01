resource "aws_instance" "dev" {
  ami = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = "demo_instance"
  }
}
