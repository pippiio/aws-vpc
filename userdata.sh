#!/bin/bash

sudo yum update -y

%{ for ssh_key in ssh_keys ~}
echo ${ssh_key} >> ~ec2-user/.ssh/authorized_keys
%{ endfor ~}
