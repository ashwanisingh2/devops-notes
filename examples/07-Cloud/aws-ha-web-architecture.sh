#!/bin/bash
# ==============================================================================
# AWS Architecture Deployment Script
# Provisions VPC, Subnets, SG, ALB, and ASG using AWS CLI
# WARNING: This script creates billable AWS resources!
# ==============================================================================

set -e

REGION="us-east-1"
VPC_CIDR="10.0.0.0/16"
SUBNET1_CIDR="10.0.1.0/24"
SUBNET2_CIDR="10.0.2.0/24"
AMI_ID="ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS us-east-1

echo "1. Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=GodMode-VPC

echo "2. Creating Subnets..."
SUBNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET1_CIDR --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
SUBNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET2_CIDR --availability-zone ${REGION}b --query 'Subnet.SubnetId' --output text)

echo "3. Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

echo "4. Updating Route Table..."
RT_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[0].RouteTableId' --output text)
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

echo "5. Creating Security Group..."
SG_ID=$(aws ec2 create-security-group --group-name alb-ec2-sg --description "Allow HTTP" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0

echo "Infrastructure provisioned!"
echo "VPC_ID: $VPC_ID"
echo "SUBNET1: $SUBNET1_ID, SUBNET2: $SUBNET2_ID"
echo "SG_ID: $SG_ID"

echo "Note: Proceed to create the Load Balancer and Auto Scaling Group using the IDs above."
