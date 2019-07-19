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
