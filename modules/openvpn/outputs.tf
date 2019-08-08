output "ssh_private_key" {
  value = "${element(concat(tls_private_key.openvpn.*.private_key_pem, list("")), 0)}"
}
output "private_ip"  {
  value = "${aws_instance.openvpn.private_ip}" 
}
output "public_ip"   {
  value = "${element(concat(aws_eip.openvpn.*.public_ip, list("")), 0)}"
}
