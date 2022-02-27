resource "aws_instance" "instance" {
	key_name = var.key

	instance_type = var.instance.type
	ami = var.instance.image

  iam_instance_profile = var.role
  vpc_security_group_ids = var.security_groups
  subnet_id = var.subnet
  private_ip = var.instance.private_ip
  associate_public_ip_address = var.instance.public_ip

  root_block_device {
    volume_type = var.instance.volume_type
    volume_size = var.instance.volume_size
    encrypted = var.instance.volume_encrypt
    delete_on_termination = var.instance.volume_delete
  }
  
  credit_specification {
    cpu_credits = var.instance.credits
  }

  metadata_options {
    http_endpoint = "enabled"
    http_put_response_hop_limit = 1
    http_tokens = "required"
  }

	user_data = <<-SCRIPT
#!/bin/bash

# Install awslogs
yum update -y && yum install -y awslogs screen nano telnet ca-certificates wget tar

# make sure it is pragues time here
/usr/bin/cp /usr/share/zoneinfo/UTC /etc/localtime

# Write timezone config file
cat << EOF > /etc/sysconfig/clock
ZONE="UTC"
UTC=true
EOF

# Write awslogs config file
cat << EOF > /etc/awslogs/awslogs.conf
[general]
state_file = /var/lib/awslogs/agent-state
[/var/log/messages]
datetime_format = %d.%m %H:%M:%S
file = /var/log/messages
buffer_duration = 5000
log_stream_name = ${var.instance.name}
initial_position = start_of_file
log_group_name = /var/log/messages
[/var/log/maillog]
datetime_format = %d.%m %H:%M:%S
file = /var/log/maillog
buffer_duration = 5000
log_stream_name = ${var.instance.name}
initial_position = start_of_file
log_group_name = /var/log/maillog
[/var/log/secure]
datetime_format = %d.%m %H:%M:%S
file = /var/log/secure
buffer_duration = 5000
log_stream_name = ${var.instance.name}
initial_position = start_of_file
log_group_name = /var/log/secure
EOF

# Write awscli config file
cat << EOF > /etc/awslogs/awscli.conf
[plugins]
cwlogs = cwlogs
[default]
region = ${var.region}
EOF

systemctl enable awslogsd
systemctl start awslogsd

wget https://github.com/prometheus/node_exporter/releases/download/v${var.instance.prometheus_version}/node_exporter-${var.instance.prometheus_version}.linux-${var.instance.architecture}.tar.gz
tar xvfz node_exporter-${var.instance.prometheus_version}.linux-${var.instance.architecture}.tar.gz
mv node_exporter-${var.instance.prometheus_version}.linux-${var.instance.architecture}/node_exporter /usr/sbin/
touch /usr/lib/systemd/system/node_exporter.service

cat << EOF > /usr/lib/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
StartLimitInterval=200
StartLimitBurst=5

[Service]
EnvironmentFile=-/etc/sysconfig/node_exporter
ExecStart=/usr/sbin/node_exporter $OPTIONS
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl enable node_exporter.service
systemctl start node_exporter.service

touch /tmp/ecs_${var.ecs}
if [[ ! -f "/tmp/ecs_false" ]]; then
# Write ECS config file
mkdir -p /etc/ecs/
cat << EOF > /etc/ecs/ecs.config
ECS_CLUSTER=${var.ecs}
EOF
# Disable default docker 
amazon-linux-extras disable docker 
# Install ECS and enable it 
amazon-linux-extras install -y ecs 
systemctl enable ecs 
reboot
fi
SCRIPT
	
  tags = {
		Name = var.instance.name
	}
}