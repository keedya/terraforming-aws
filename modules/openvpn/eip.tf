resource "aws_eip" "openvpn" {
  instance = "${aws_instance.openvpn.id}"
  count    = "1"
  vpc      = true

  tags = {
    Name = "${var.name}-op-eip"
  }
}

