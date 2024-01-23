#!/bin/bash

# Update packages & install iptables
yum update -y
yum install -y iptables

# Query network interface data
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --no-source-dest-check

# Associate EIP
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${eip} --allow-reassociation --region ${aws_region}

# Attach NAT ENI 
aws ec2 attach-network-interface --network-interface-id ${eni} --instance-id $INSTANCE_ID --device-index 1 --region ${aws_region}

# Configure NAT for default ENI
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
