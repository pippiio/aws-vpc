#!/bin/bash

# Add trusted ssh keys 
%{ for ssh_key in ssh_keys ~}
echo ${ssh_key} >> ~ec2-user/.ssh/authorized_keys
%{ endfor ~}

# Update packages
yum update -y

# Query network interface data
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Associate EIP
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${eip} --allow-reassociation --region ${aws_region}
