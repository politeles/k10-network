output "vpc_id" {
  value = aws_vpc.main.id
}

output "route53_id" {
  value = aws_route53_zone.private-zone.zone_id
}