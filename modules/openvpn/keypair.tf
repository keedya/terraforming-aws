variable "keyname" {default = "openvpn-key"}

resource "aws_key_pair" "openvpn" {
  key_name   = "${var.keyname}"
  public_key = "${tls_private_key.openvpn.public_key_openssh}"
}

resource "tls_private_key" "openvpn" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}
