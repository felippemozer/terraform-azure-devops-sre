#!/bin/sh
sudo yum install -y httpd
sudo systemctl enable httpd
sudo systemctl start httpd
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo chmod -R 777 /var/www/html
sudo echo "Welcome to StackAmplify - WebVM App1 - VM Hostname: $(hostname)" > /var/www/html/index.html
sudo mkdir /var/www/html/app1
sudo echo "Welcome to StackAmplify - WebVM App1 - VM Hostname: $(hostname)" > /var/www/html/app1/hostname.html
sudo echo "Welcome to StackAmplify - WebVM App1 - App Status Page" > /var/www/html/app1/status.html
sudo curl -H "Metadata:true" --noproxy "*" "https://169.254.169.254/metadata/instance?api-version=2020-09-01" -o /var/www/html/app1/metadata.html