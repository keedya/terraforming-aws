#!/bin/bash -x

# prerequisists:
# apt install jq

# Variables
PROPERTY_REQUEST=".tmp/set_propert_request.json"
PROPERTY_TEMPLATE="bosh-templates/properties-template.json"
INSTALLATION_REQUEST="bosh-templates/director_installation.json"
AVAILABILITY_ZONES=".tmp/availability_zones.json"
AVAILABILITY_ZONES_TEMPLATES="bosh-templates/availability_zones-template.json"
NETWORKS_REQUEST=".tmp/set_network_request.json"
NETWORKS_TEMPLATE="bosh-templates/networks-template.json"
ASSIGN_NETWORK_AVAILABILITY_ZONES="bosh-templates/network_ava_zones-template.json"


############### Configure properties ###############################

# Copy template to request

cp ${PROPERTY_TEMPLATE} ${PROPERTY_REQUEST}


echo $(jq --arg key "security_group" --arg value "$(terraform output vms_security_group_id)" '.iaas_configuration[$key] = $value' ${PROPERTY_REQUEST}) > ${PROPERTY_REQUEST}
echo $(jq --arg key "key_pair_name" --arg value "$(terraform output ops_manager_ssh_public_key_name)" '.iaas_configuration[$key] = $value' ${PROPERTY_REQUEST}) > ${PROPERTY_REQUEST}
echo $(jq --arg key "ssh_private_key" --arg value "$(terraform output ops_manager_ssh_private_key)" '.iaas_configuration[$key] = $value' ${PROPERTY_REQUEST}) > ${PROPERTY_REQUEST}
echo $(jq --arg key "iam_instance_profile" --arg value "$(terraform output ops_manager_iam_instance_profile_name)" '.iaas_configuration[$key] = $value' ${PROPERTY_REQUEST}) > ${PROPERTY_REQUEST}


curl -k https://${OPS_MANAGER_IP}/api/v0/staged/director/properties \
	-X PUT -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
       	-d@${PROPERTY_REQUEST}

############### Configure availability zones #######################

cp ${AVAILABILITY_ZONES_TEMPLATES} ${AVAILABILITY_ZONES}

curl -k https://${OPS_MANAGER_IP}/api/v0/staged/director/availability_zones \
        -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
        -d@${AVAILABILITY_ZONES}

echo $(jq --arg key "name" --arg value "us-west-2c" '.availability_zone[$key] = $value' ${AVAILABILITY_ZONES}) > ${AVAILABILITY_ZONES}

curl -k https://${OPS_MANAGER_IP}/api/v0/staged/director/availability_zones \
        -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
        -d@${AVAILABILITY_ZONES}

############## Configure network ###################################

cp ${NETWORKS_TEMPLATE} ${NETWORKS_REQUEST}

# infrastructure
echo $(jq --arg key "iaas_identifier" --arg value "$(terraform output -json | jq -r .infrastructure_subnet_ids.value[0])" '.networks[0].subnets[0][$key] = $value' ${NETWORKS_REQUEST}) > ${NETWORKS_REQUEST}
echo $(jq --arg key "iaas_identifier" --arg value "$(terraform output -json | jq -r .infrastructure_subnet_ids.value[1])" '.networks[0].subnets[1][$key] = $value' ${NETWORKS_REQUEST}) > ${NETWORKS_REQUEST}

# pks

echo $(jq --arg key "iaas_identifier" --arg value "$(terraform output -json | jq -r .pks_subnet_ids.value[0])" '.networks[1].subnets[0][$key] = $value' ${NETWORKS_REQUEST}) > ${NETWORKS_REQUEST}
echo $(jq --arg key "iaas_identifier" --arg value "$(terraform output -json | jq -r .pks_subnet_ids.value[1])" '.networks[1].subnets[1][$key] = $value' ${NETWORKS_REQUEST}) > ${NETWORKS_REQUEST}

# service

echo $(jq --arg key "iaas_identifier" --arg value "$(terraform output -json | jq -r .services_subnet_ids.value[0])" '.networks[2].subnets[0][$key] = $value' ${NETWORKS_REQUEST}) > ${NETWORKS_REQUEST}
echo $(jq --arg key "iaas_identifier" --arg value "$(terraform output -json | jq -r .services_subnet_ids.value[1])" '.networks[2].subnets[1][$key] = $value' ${NETWORKS_REQUEST}) > ${NETWORKS_REQUEST}

curl -k https://${OPS_MANAGER_IP}/api/v0/staged/director/networks \
        -X PUT -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
        -d@${NETWORKS_REQUEST}

################# Assign AZ and Network ###########################

curl -k https://${OPS_MANAGER_IP}/api/v0/staged/director/network_and_az \
        -X PUT -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
        -d@${ASSIGN_NETWORK_AVAILABILITY_ZONES}



################# FINALLY apply installation ###########################

curl -k https://${OPS_MANAGER_IP}/api/v0/installations \
        -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
	-d@${INSTALLATION_REQUEST}

############### Monitor installation #################################


GET_STATUS="curl -k https://${OPS_MANAGER_IP}/api/v0/installations \
        -X GET -H \"Content-Type: application/json\" \
        -H \"Authorization: Bearer ${UAA_ACCESS_TOKEN}\""

while :
do
  status=$(eval ${GET_STATUS} | jq '.installations[0].status')
  echo "Status ${status}"
  if [[ ${status} =~ "succeeded" ]];
  then
      echo "Mission accomplished"
      exit 0
  fi
  sleep 20s

done
