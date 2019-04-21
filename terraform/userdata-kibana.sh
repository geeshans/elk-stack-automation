#!/bin/bash

sed -i -e 's/ip0/${es_cluster_ip0}/' /etc/kibana/kibana.yml

service kibana restart