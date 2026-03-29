variable "vpc_cidr_block" {
    default = "10.0.0.0/16"
}
variable "subnet_cidr_block" {
    default = "10.0.10.0/24"
}
variable "subnet_cidr_block_2" {
    default = "10.0.20.0/24"
}
variable "avail_zone" {
    default = "ap-southeast-1a"
}
variable "avail_zone_2" {
    default = "ap-southeast-1b"
}
variable "env_prefix" {
    default = "dev"
}
variable "my_ip" {
    default = "43.250.242.220/32"
}
variable "instance_type" {
    default = "t3.small"
}

variable "region" {
    default = "ap-southeast-1"
}
