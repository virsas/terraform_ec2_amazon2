# terraform_ec2_amazon2

Terraform module to create amazon-2 based EC2 instance.

## Dependencies

- VPC <https://github.com/virsas/terraform_vpc>
- VPC SUBNET <https://github.com/virsas/terraform_vpc_subnet>
- VPC SG <https://github.com/virsas/terraform_vpc_sg>
- SSHKEY <https://github.com/virsas/terraform_ec2_sshkey>
- IAM ROLE <https://github.com/virsas/terraform_iam_role>

If you are creating an instance for the ECS cluster, you require an ECS module.
- ECS Cluster <https://github.com/virsas/terraform_ecs_cluster>

## Terraform example

``` terraform
##################
# EC2 Variable
##################
variable "ec2_ecs_api1" { 
  default = {
    # Name of the instance
    name = "api1"
    # Credit option for CPU usage. Valid values: standard, unlimited
    credits = "standard"
    # Instance size
    type = "t4g.small"
    # OS AMI of Amazon based linux distro. For anything else use github.com/virsas/terraform_ec2_instance
    image = "ami-07e30a3659a490be7"
    # Private IP address from the subnet allocated to this instance
    private_ip = "10.0.0.4"
    # Allow public IP address (true/false)
    public_ip = "false"
    # Type of block device mounted to the instance
    volume_type = "gp2"
    # Size of the block device
    volume_size = "30"
    # Enable or disable encryption
    volume_encrypt = true
    # Enable deletion of block device on instance termination
    volume_delete = true
    # prometheus is enabled by default, here you can set the version.
    prometheus_version = "1.3.1"
    # AMI architecture, used for the prometheus install script download
    architecture = "arm64"
  } 
}

##################
# EC2 Instance
##################
module "ec2_ecs_api1" {
  source          = "github.com/virsas/terraform_ec2_amazon2"

  instance        = var.ec2_ecs_api1

  # initial ssh key used to access this instance
  key             = module.ec2_sshkey_user1.name

  # list of security groups
  security_groups = [ module.vpc_sg_admin.id, module.vpc_sg_api.id ]
  # VPC subnet membership. Must be the very same block as the IP configuration of the private_ip
  subnet          = module.vpc_subnet_api_a.id

  # Set "false" if you want to use this instance for anything else or the name of the ECS cluster
  ecs             = module.ecs_cluster_apis.name
  # IAM role needed for ECS access or logging to cloudwatch
  role            = module.iam_role_ecs.name
  
  # region where the instance should be located
  region          = var.region
}
```
