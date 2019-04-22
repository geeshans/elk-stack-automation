# ELK Stack Automation

This project will create an ELK stack in AWS using Packer, Ansible and Terraform. For the moment there are two different parts to the pipeline
1. Creating  Amazon Machine Images using Packer
2. Using those AMIs to create the cluster


## Prerequisites

To run this project you will need the below tools installed in you machine:
- [Packer](https://www.packer.io/downloads.html)
- [Ansible](http://docs.ansible.com/ansible/latest/intro_installation.html)
- [Terraform](https://www.terraform.io/intro/index.html)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)
- [jq](https://stedolan.github.io/jq/)

In addition to this the EC2 that you are running this from need to have a [Role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) assigned to it with the relevent permissions to create resources.

Also you need to create two Keypairs in your AWS account as "terraform" and "packer"

## Creating  Amazon Machine Images using Packer

```shell
git clone https://github.com/geeshans/elk-stack-automation.git
cd ./elk-stack-automation/packer/
 chmod u+x run-packer-base.sh
 ./run-packer-base.sh
```
Etimated Runtime: 20 mins


## Using Terraform to create the cluster
```shell
cd ../terraform/
#Update the variables.tf file with the newly created AMI IDs
terraform init
terraform apply .
```

## Monitoring
Monitoring for Elasticsearch and Kibana can be enabled via the XPack feature
http://<KIBANA_SERVER>:5601/app/monitoring#/overview?_g=(cluster_uuid:hMq87SaMQXuH9ws2rg8VFw)



## ToDo
1. Backup and Monitoring of the resources
2. Use a Base image and build from it to improve packer time
3. Restructure the files to reduce redundunt files
4. Improve on the how Elastic nodes are configured in logstash
5. Documentation for different Ansible Roles
6. Use standard HTTP ports and set up a TLS for all services