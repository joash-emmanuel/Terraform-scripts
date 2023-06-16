variable "AWS_ACCESS_KEY" {
    default = "ACCESS-KEY"
}


variable "AWS_SECRET_KEY" {
    default = "SECRET-KEY"
}

variable "AWS_REGION" {
  default = "us-west-2"
}


variable "region" {
  description = "AWS Deployment region.."
  default = "us-west-2"
}


variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["11.0.1.0/24", "11.0.2.0/24"]
}
 
variable "private_subnet_cidrs" {
 type        = list(string)
 description = "Private Subnet CIDR values"
 default     = ["11.0.10.0/24", "11.0.20.0/24"]
}


variable "availability_zones" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["us-west-2a", "us-west-2b"]
}