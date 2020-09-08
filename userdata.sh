#!/bin/sh

yum install -y python3 python3-devel gcc
pip3 install locust
cat <<EOF > /root/locustfile.py
import random
from locust import task, constant
from locust.contrib.fasthttp import FastHttpUser

class QuickstartUser(FastHttpUser):
    wait_time = constant(1)

    @task
    def index_page(self):
        self.client.get("/")
EOF