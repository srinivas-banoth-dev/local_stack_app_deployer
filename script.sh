@echo off
docker-compose up
# to required
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
aws configure --profile localstack
