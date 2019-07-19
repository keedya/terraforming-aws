SUBNET1=$(terraform output -json | jq -r '.public_subnet_ids["value"][0]')
SUBNET2=$(terraform output -json | jq -r '.public_subnet_ids["value"][1]')
PROFILE=${ADMIN_USER}
TLD=desa.nautilusbeta.com
VPC_ID=$(terraform output vpc_id)
HOSTED_ZONE_ID=$(terraform output dns_zone_id)
REGION=us-west-2
