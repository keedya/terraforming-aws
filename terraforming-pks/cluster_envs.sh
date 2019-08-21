SUBNET1=$(terraform output -json | jq -r '.public_subnet_ids["value"][0]')
SUBNET2=$(terraform output -json | jq -r '.public_subnet_ids["value"][1]')
SECURITY_GROUP=$(terraform output vms_security_group_id)
PROFILE=${ADMIN_USER}
TLD=desa.nautilusbeta.com
VPC_ID=$(terraform output vpc_id)
HOSTED_ZONE_ID=$(terraform output dns_zone_id)
REGION=$(terraform output region)
