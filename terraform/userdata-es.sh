#!/bin/bash
HOSTNAME=`curl  http://169.254.169.254/latest/meta-data/hostname`

echo ES_JAVA_OPTS="\"-Xms1g -Xmx1g\"" >> /etc/sysconfig/elasticsearch
echo MAX_LOCKED_MEMORY=unlimited >> /etc/sysconfig/elasticsearch

# Discovery EC2 plugin is used for the nodes to create the cluster in AWS
echo -e "yes\n" | /usr/share/elasticsearch/bin/elasticsearch-plugin  install discovery-ec2

# Shortest configuration for Elasticsearch nodes to find each other
echo "discovery.zen.hosts_provider: ec2" >> /etc/elasticsearch/elasticsearch.yml
echo "network.host: ${HOSTNAME}" >> /etc/elasticsearch/elasticsearch.yml

sudo service elasticsearch restart
