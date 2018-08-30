# output provides a way to query what we care about

output "vpc_id" {
  value = "${aws_vpc.vpc.id}"
}

output "public_subnet_ids" {
  value = "${aws_subnet.public_subnet.*.id}"
}

output "private_subnet_ids" {
  value = "${aws_subnet.private_subnet.*.id}"
}

output "default_sg_id" {
  value = "${aws_security_group.default.id}"
}

output "security_group_ids" {
  value = ["${aws_security_group.default.id}"]
}
