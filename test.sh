mysub=$(aws ec2 describe-subnets --filter "Name=cidr-block,Values=10.0.4.0/22" | grep "SubnetId" | cut -d '"' -f 4)
echo $mysub

