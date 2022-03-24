# POC VPN/Intranet

## CloudFormation for fake-datacenter

- VPC: 172.17.0.0
- public subnet: 172.17.100.0/24
- VPN: openSwan / IPSEC
- 2 EC2 instances
  - 1 EC2 as VPN server with EIP but no SourceDestCheck

## CloudFormation for Main AWS VPC

- VPC: 10.0.0.0/16
- 1 internet GW for VPC
- 1 couple of subnets (private and public) for future Wordpress + RDS: called "A" for AZ A
  - 10.0.0.0/24 for private subnet
  - 10.0.100.0/24 for public subnet + Nat GW + EIP
- 1 couple of subnets (private and public) for future Wordpress + RDS: called "B" for AZ B
  - 10.0.1.0/24 for private subnet
  - 10.0.101.0/24 for public subnet + Nat GW + EIP
- 1 private subnet for intranet and client VPN: called "C" for AZ C
  - 10.0.2.0/24 for private subnet

## CloudFormation for fake-intranet

- needs
  1. VpcIdentifier
  2. SubnetIdentifier
  3. IpAddressDataCenter
- optional
  1. AmiIdentifier (default: Amazon 64bits AMI)
  2. InstanceIdentifier (default: t2.micro)
  3. KeyNameIdentifier (default: ami-amazon)
- 2 EC2 instances
  - 1 EC2 as VpnClient + EIP
- 1 Customer GW
- 1 Virtual GW
- 1 VPN Connection

### How to make POC

1. Create fake datacenter
```
aws cloudformation create-stack --stack-name fake-datacenter --template-body file://fake-datacenter.yml
```
2. Create full VPC with 3 AZ
```
aws cloudformation create-stack --stack-name ocr-vpc --template-body file://full-vpc-3az.yml
```
3. Wait for stacks to be in state `CREATE_COMPLETE`
```
aws cloudformation describe-stacks | jq '.Stacks[] | {name: .StackName, status: .StackStatus}'

# output
{
  "name": "ocr-vpc",
  "status": "CREATE_COMPLETE"
}
{
  "name": "fake-datacenter",
  "status": "CREATE_COMPLETE"
}
```
4. Retrieve data we need to call last template
```
aws ec2 describe-vpcs | jq '.Vpcs[] | {ip: .CidrBlock, id: .VpcId}'
{
  "ip": "10.0.0.0/16",
  "id": "vpc-008defb045a3dda0e"
}
{
  "ip": "172.31.0.0/16",
  "id": "vpc-cda261a5"
}
{
  "ip": "172.17.0.0/16",
  "id": "vpc-09f7903d5a02efbdf"
}

aws ec2 describe-subnets | jq '.Subnets[] | {id: .SubnetId, ip: .CidrBlock, az: .AvailabilityZone, vpcid: .VpcId}'
{
  "id": "subnet-06edc8154728f5c7a",
  "ip": "10.0.2.0/24",
  "az": "eu-west-3c",
  "vpcid": "vpc-008defb045a3dda0e"
}
{
  "id": "subnet-e3c9c898",
  "ip": "172.31.16.0/20",
  "az": "eu-west-3b",
  "vpcid": "vpc-cda261a5"
}
{
  "id": "subnet-5d3cd235",
  "ip": "172.31.0.0/20",
  "az": "eu-west-3a",
  "vpcid": "vpc-cda261a5"
}
{
  "id": "subnet-080e13cb6a9338a98",
  "ip": "172.17.100.0/24",
  "az": "eu-west-3a",
  "vpcid": "vpc-09f7903d5a02efbdf"
}
{
  "id": "subnet-474c060a",
  "ip": "172.31.32.0/20",
  "az": "eu-west-3c",
  "vpcid": "vpc-cda261a5"
}
{
  "id": "subnet-042e7fbbcdad256d4",
  "ip": "10.0.0.0/24",
  "az": "eu-west-3a",
  "vpcid": "vpc-008defb045a3dda0e"
}
{
  "id": "subnet-00d1a3132338738dc",
  "ip": "10.0.100.0/24",
  "az": "eu-west-3a",
  "vpcid": "vpc-008defb045a3dda0e"
}
{
  "id": "subnet-04555f0165f915e57",
  "ip": "10.0.101.0/24",
  "az": "eu-west-3b",
  "vpcid": "vpc-008defb045a3dda0e"
}
{
  "id": "subnet-0ea33ab81767b3465",
  "ip": "10.0.1.0/24",
  "az": "eu-west-3b",
  "vpcid": "vpc-008defb045a3dda0e"
}


aws ec2 describe-addresses | jq '.Addresses[] | {ip: .PublicIp, privIp: .PrivateIpAddress}'
{
  "ip": "15.188.69.53",
  "privIp": "172.17.100.87"
}
{
  "ip": "15.236.236.118",
  "privIp": "10.0.101.227"
}
{
  "ip": "52.47.187.6",
  "privIp": "10.0.100.56"
}
```
5. Export variables
```
export IpAddressDataCenter=$(aws ec2 describe-addresses | jq '.Addresses[] | {ip: .PublicIp, privIp: .PrivateIpAddress}' | grep -B 1 172.17 | head -n 1 | grep -o -E "([0-9]{1,3}.){3}[0-9]{1,3}")
export VpcIdentifier=$(aws ec2 describe-vpcs | jq '.Vpcs[] | {ip: .CidrBlock, id: .VpcId}' | grep -A 1  10.0.0.0 | tail -n 1 | grep -o -E 'vpc-[^"]+')
export SubnetIdentifier=$(aws ec2 describe-subnets | jq '.Subnets[] | {id: .SubnetId, ip: .CidrBlock, az: .AvailabilityZone, vpcid: .VpcId}' | grep -A 2 -B 2 10.0.0.0 | grep -o -E 'subnet-[^"]+')
```
6. Create stack
```
aws cloudformation create-stack --stack-name ocr-intranet --template-body file://fake-intranet.yml --parameters ParameterKey=VpcIdentifier,ParameterValue=$VpcIdentifier ParameterKey=SubnetIdentifier,ParameterValue=$SubnetIdentifier ParameterKey=IpAddressDataCenter,ParameterValue=$IpAddressDataCenter
```
7. Wait for stack to be created
```
aws cloudformation describe-stacks | jq '.Stacks[] | {name: .StackName, status: .StackStatus}'

# output

{
  "name": "ocr-intranet",
  "status": "CREATE_COMPLETE"
}
{
  "name": "ocr-vpc",
  "status": "CREATE_COMPLETE"
}
{
  "name": "fake-datacenter",
  "status": "CREATE_COMPLETE"
}
```
8. Look for VPN Connection ID
```
aws ec2 describe-vpn-connections | jq '.VpnConnections[] | {id: .VpnConnectionId}'
{
  "id": "vpn-024a20485d89be954"
}

export VpnConnectionIdentifier=$(aws ec2 describe-vpn-connections | jq '.VpnConnections[] | {id: .VpnConnectionId}' | grep -o -E 'vpn-[^"]+')
```
9. Modify VPN Connection Option
```
aws ec2 modify-vpn-connection-options --vpn-connection-id $VpnConnectionIdentifier --local-ipv4-network-cidr 172.17.0.0/16 --remote-ipv4-network-cidr 10.0.0.0/16
```
10. Get Route Table ID from VPC
```
aws ec2 describe-route-tables --filter Name=vpc-id,Values=$VpcIdentifier Name=association.main,Values=true | jq '.RouteTables[] | {id: .RouteTableId}'
{
  "id": "rtb-00b70dbb441a2eb18"
}

export RouteTableIdentifier=$(aws ec2 describe-route-tables --filter Name=vpc-id,Values=$VpcIdentifier Name=association.main,Values=true | jq '.RouteTables[] | {id: .RouteTableId}' | grep -o -E 'rtb-[^"]+')
```
11. Get VGW ID
```
aws directconnect describe-virtual-gateways
{
    "virtualGateways": [
        {
            "virtualGatewayId": "vgw-0fdba6acd41a5c08d",
            "virtualGatewayState": "available"
        }
    ]
}

export VirtualGatewayIdentifier=$(aws directconnect describe-virtual-gateways | grep -o -E 'vgw-[^"]+')

```
12. Propagate Route
```
aws ec2 enable-vgw-route-propagation --gateway-id $VirtualGatewayIdentifier --route-table-id $RouteTableIdentifier
```
13. Download VPN server configuration for openSwan
14. Connect SSH to future VPN server
```
ssh -i ami-amazon.pem ec2-user@$IpAddressDataCenter
```
15. Execute vpn.sh
```
sudo vpn.sh
```
