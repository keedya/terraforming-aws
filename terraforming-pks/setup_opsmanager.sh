#!/bin/bash -x

# prerequisists:
# apt install jq

SETUP_REQUEST=".tmp/setup_request.json"

# setup ops manager with internal auth
# fetch ops_manager IP from terraform

export OPS_MANAGER_IP=$(terraform output ops_manager_public_ip)

# build setup request, there is no authentication needed here
jq -n '{setup:{}}' > ${SETUP_REQUEST}

echo $(jq --arg key "decryption_passphrase" --arg value "${ADMIN_PASSWORD}" '.setup[$key] = $value' ${SETUP_REQUEST}) > ${SETUP_REQUEST}
echo $(jq --arg key "decryption_passphrase_confirmation" --arg value "${ADMIN_PASSWORD}" '.setup[$key] = $value' ${SETUP_REQUEST}) > ${SETUP_REQUEST}
echo $(jq --arg key "admin_password" --arg value "${ADMIN_PASSWORD}" '.setup[$key] = $value' ${SETUP_REQUEST}) > ${SETUP_REQUEST}
echo $(jq --arg key "admin_password_confirmation" --arg value "${ADMIN_PASSWORD}" '.setup[$key] = $value' ${SETUP_REQUEST}) > ${SETUP_REQUEST}
echo $(jq --arg key "admin_user_name" --arg value "${ADMIN_USER}" '.setup[$key] = $value' ${SETUP_REQUEST}) > ${SETUP_REQUEST}
echo $(jq --arg key "eula_accepted" --arg value "true" '.setup[$key] = $value' ${SETUP_REQUEST}) > ${SETUP_REQUEST}
echo $(jq --arg key "identity_provider" --arg value "internal" '.setup[$key] = $value' ${SETUP_REQUEST}) > ${SETUP_REQUEST}

#post the command
curl -k "https://${OPS_MANAGER_IP}/api/v0/setup" -X POST -H "Content-Type: application/json" -d@${SETUP_REQUEST}

# TODO get token using uaac
# install uaac
# apt install ruby rubydev
# gem install cf-uaac
sleep 30s
uaac target https://${OPS_MANAGER_IP}/uaa --skip-ss-validation
uaac token owner  get opsman -s "" ${ADMIN_USER} -p ${ADMIN_PASSWORD}
export UAA_ACCESS_TOKEN=$(cat ~/.uaac.yml | yq r - -j | jq -r ".[\"https://${OPS_MANAGER_IP}/uaa\"].contexts[\"${ADMIN_USER}\"].access_token")


echo $OPS_MANAGER_IP
echo $UAA_ACCESS_TOKEN
