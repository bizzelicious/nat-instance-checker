#!/bin/bash
MyInstanceId=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
RouteTableId="rtb-0e39060c45e2836d4"
Region="eu-west-1"

while : ;do
    ActiveInstanceId=$(aws ec2 describe-route-tables --route-table-id "$RouteTableId" --query 'RouteTables[*].Routes[?DestinationCidrBlock == `0.0.0.0/0`].InstanceId[]' --output text --region "$Region")

    if [ "$MyInstanceId" = "$ActiveInstanceId" ]; then
        echo "I'm the active NAT instance. Exit"
    else
        ActiveInstanceIp=$(aws ec2 describe-instances --instance-id "$ActiveInstanceId" --query 'Reservations[*].Instances[*].PrivateIpAddress[]' --output text --region "$Region")

        while ping -c 1 -w 3 "$ActiveInstanceIp" &>/dev/null; do
            echo "Successfully pinged $ActiveInstanceId on $ActiveInstanceIp"
            sleep 1
        done
        echo "Failed to ping $ActiveInstanceId on $ActiveInstanceIp. Will failover to this instance now!"
        aws ec2 associate-address --allocation-id eipalloc-0ae72c9f7ff0cfe9b --instance-id "$MyInstanceId" --allow-reassociation --region "$Region" & aws ec2 replace-route --route-table-id "$RouteTableId" --instance-id "$MyInstanceId" --destination-cidr-block 0.0.0.0/0 --region "$Region" || aws ec2 create-route --route-table-id "$RouteTableId" --instance-id "$MyInstanceId" --destination-cidr-block 0.0.0.0/0 --region "$Region"
    fi
    sleep 3
done
