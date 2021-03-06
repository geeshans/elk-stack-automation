#!/bin/bash -eux

# set the session to be noninteractive
export DEBIAN_FRONTEND="noninteractive"

# record the start time
start=`date +%s`

### set region
export AWS_REGION="us-east-1"

### list first VPC id
export BUILD_VPC_ID=$(aws ec2 describe-vpcs \
  --filters 'Name=isDefault,Values=true' \
	--query 'Vpcs[0].[VpcId]' \
	--output text);
echo $BUILD_VPC_ID;

### list first subnet id, within VPC
export BUILD_SUBNET_ID=$(aws ec2 describe-subnets \
	--filters "Name=vpc-id,Values=$BUILD_VPC_ID" \
	--query 'Subnets[0].[SubnetId]' \
	--output text);
echo $BUILD_SUBNET_ID;

### set the ssh keyname and file
export SSH_KEYPAIR_NAME="packer"
export SSH_PRIVATE_KEY_FILE="$HOME/.ssh/packer.pem"



### build Packer AMI

packer validate packer-elasticsearch-ami.json
packer validate packer-logstash-ami.json
packer validate packer-kibana-ami.json

packer inspect packer-elasticsearch-ami.json
packer inspect packer-logstash-ami.json
packer inspect packer-kibana-ami.json

packer build -only=amazon-ebs packer-elasticsearch-ami.json
packer build -only=amazon-ebs packer-logstash-ami.json
packer build -only=amazon-ebs packer-kibana-ami.json

# print AMI ID
export ELK_AMI_ID=$(jq '.builds[-1].artifact_id' -r manifest.json | cut -d':' -f2);
echo $ELK_AMI_ID;

# print total build time
end=`date +%s`
secs=$((end-start))
printf 'runtime = %02dh:%02dm:%02ds\n' $(($secs/3600)) $(($secs%3600/60)) $(($secs%60))