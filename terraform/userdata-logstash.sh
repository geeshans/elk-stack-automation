#!/bin/bash

sed -i -e 's/ip0/${es_cluster_ip0}/' /etc/logstash/conf.d/30-elasticsearch-output.conf
sed -i -e 's/ip1/${es_cluster_ip1}/' /etc/logstash/conf.d/30-elasticsearch-output.conf
sed -i -e 's/ip2/${es_cluster_ip2}/' /etc/logstash/conf.d/30-elasticsearch-output.conf

service logstash restart