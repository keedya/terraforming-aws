#--------------------------------------------------------------
# This module creates all resources necessary for OpenVPN
#--------------------------------------------------------------

variable "name"               { default = "openvpn" }
variable "vpc_id"             { default = ""}
variable "vpc_cidr"           { default = ""}
variable "public_subnet_id"  {
  type = "list"
}
variable "key_name"           { default = ""}
variable "ami"                { default = ""}
variable "instance_type"      { default = ""}
variable "bastion_host"       { default = ""}
variable "bastion_user"       { default = ""}
variable "openvpn_admin_user" { default = "openvpn"}
variable "openvpn_admin_pw"   { default = "password"}
variable "vpn_cidr"           { default = ""}

resource "aws_security_group" "openvpn" {
  name   = "${var.name}"
  vpc_id = "${var.vpc_id}"
  description = "OpenVPN security group"

  tags { Name = "${var.name}" }

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  # For OpenVPN Client Web Server & Admin Web UI
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "udp"
    from_port   = 1194
    to_port     = 1194
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "openvpn" {
  ami           = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.openvpn.key_name}"
  subnet_id     = "${element(var.public_subnet_id, count.index)}"

  vpc_security_group_ids = ["${aws_security_group.openvpn.id}"]

  tags { Name = "${var.name}" }

  # `admin_user` and `admin_pw` need to be passed in to the appliance through `user_data`, see docs -->
  # https://docs.openvpn.net/how-to-tutorialsguides/virtual-platforms/amazon-ec2-appliance-ami-quick-start-guide/
  user_data = <<USERDATA
admin_user=${var.openvpn_admin_user}
admin_pw=${var.openvpn_admin_pw}
USERDATA
}

