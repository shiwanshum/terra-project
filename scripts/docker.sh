#!/bin/bash

# update packages 
sudo apt-get update -y

# installing packages
sudo apt-get install  docker -y 

# start the docker-demon  
sudo service docker start
