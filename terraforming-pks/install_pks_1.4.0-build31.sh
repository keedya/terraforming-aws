#!/bin/bash -x



PKS_BINARY="pivotal-container-service-1.4.0-build.31.pivotal"
STEMCELL="light-bosh-stemcell-250.25-aws-xen-hvm-ubuntu-xenial-go_agent.tgz"
STEMCELL_VERSION="250.25"

# upload the image
om -t https://${OPS_MANAGER_IP} -u ${ADMIN_USER} -p ${ADMIN_PASSWORD} -k upload-product -p ${PKS_PRODUCT}/${PKS_BINARY}


##################### stage product #######################################

# Get product name

PRODUCT_NAME=$(curl -k https://${OPS_MANAGER_IP}/api/v0/available_products \
	       -X GET \
	       -H "Content-Type: application/json" \
	       -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" | jq -r .[0].name)

PRODUCT_VERSION=$(curl -k https://${OPS_MANAGER_IP}/api/v0/available_products \
               -X GET \
               -H "Content-Type: application/json" \
	       -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" | jq -r .[0].product_version)

# stage product
om -t https://${OPS_MANAGER_IP} -u ${ADMIN_USER} -p ${ADMIN_PASSWORD} \
   -k stage-product --product-name ${PRODUCT_NAME} \
   --product-version ${PRODUCT_VERSION}


# Upload stemacell

om -t https://${OPS_MANAGER_IP} -u ${ADMIN_USER} -p ${ADMIN_PASSWORD} -k upload-stemcell --stemcell ${PKS_PRODUCT}/${STEMCELL}

# assign stemcell

om -t https://${OPS_MANAGER_IP} -u ${ADMIN_USER} -p ${ADMIN_PASSWORD} -k assign-stemcell --stemcell ${STEMCELL_VERSION} --product ${PRODUCT_NAME}



############################### Configure pks #####################################


PRODUCT_GUID=$(curl -k https://${OPS_MANAGER_IP}/api/v0/staged/products \
               -X GET \
               -H "Content-Type: application/json" \
               -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" | jq -r .[1].guid)


# set network and AZ

curl -k https://${OPS_MANAGER_IP}/api/v0/staged/products/${PRODUCT_GUID}/networks_and_azs \
     -X PUT -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
     -d @pks_templates/network_and_azs.json

# set properties

PROPERTY_REQUEST_TEMPLATE="pks_templates/properties.json"
PROPERTY_REQUEST=".tmp/pks_property_re.json"

cp ${PROPERTY_REQUEST_TEMPLATE} ${PROPERTY_REQUEST}

# Set pks worker role
echo $(jq ".properties[\".properties.cloud_provider.aws.iam_instance_profile_worker\"].value = \"$(terraform output pks_worker_iam_instance_profile_name)\"" ${PROPERTY_REQUEST}) > ${PROPERTY_REQUEST}

# Set pks master role
echo $(jq ".properties[\".properties.cloud_provider.aws.iam_instance_profile_master\"].value = \"$(terraform output pks_master_iam_instance_profile_name)\"" ${PROPERTY_REQUEST}) > ${PROPERTY_REQUEST}

# Set pks api endpoint
echo $(jq ".properties[\".properties.pks_api_hostname\"].value = \"$(terraform output pks_api_endpoint)\"" ${PROPERTY_REQUEST}) > ${PROPERTY_REQUEST}


# PKS_CERT
# PKS_PRIV_KEY
# Set pks private key
echo $(jq  ".properties[\".pivotal-container-service.pks_tls\"].value.private_key_pem = \"${PKS_PRIV_KEY}\"" ${PROPERTY_REQUEST}) > ${PROPERTY_REQUEST}

# Set pks Cert
echo $(jq ".properties[\".pivotal-container-service.pks_tls\"].value.cert_pem = \"${PKS_CERT}\"" ${PROPERTY_REQUEST}) > ${PROPERTY_REQUEST}

curl -k https://${OPS_MANAGER_IP}/api/v0/staged/products/${PRODUCT_GUID}/properties \
     -X PUT -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
     -d @${PROPERTY_REQUEST} | jq -r


################# FINALLY apply installation ###########################
INSTALLATION_REQUEST="pks_templates/pks_installation.json"

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
