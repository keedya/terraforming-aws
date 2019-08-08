#! /bin/bash -x
  
#
# Create cluster, elb to access cluster master and set route53 alias
#

# Please create a cluster-env-file with values specific to your environment
# which contains the key=value pairs as shown below
#SUBNET1=subnet-0265b3d7e85c47972
#SUBNET2=subnet-0b6b6c4e87f795aa5
#PROFILE=platform-dev
#TLD=internal.nautilusbeta.com
#VPC_ID=vpc-0cdb6a33f98b827e8
#HOSTED_ZONE_ID=Z3UHJUQS7O1706
#REGION=us-west-2

set +e
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

usage() { echo "Usage: $0 [-c <cluster-name> -p <small|medium|qe-large]> -e <cluster-env-file> -n <number of workers>" 1>&2; exit 1; }

while getopts c:e:p:n: option
do
    case "${option}" in
        c) cluster_name=${OPTARG};;
        e) cluster_env_file=${OPTARG};;
        p) cluster_plan=${OPTARG};;
	n) cluster_workers=${OPTARG};;
    esac
done

if [ -z ${cluster_name} ] || [ -z ${cluster_plan} ] || [ -z ${cluster_env_file} ] || [ -z ${cluster_workers} ]; then
    usage
fi

if [ -f ${cluster_env_file} ]; then
    source ${cluster_env_file}
else
    echo "file does not exist: ${cluster_env_file}"
    usage
fi

echo "cluster name: ${cluster_name}"
pks login -a api.pks.${PROFILE}.${TLD} -u ${PROFILE} -p ${ADMIN_PASSWORD} --skip-ssl-validation

cluster_uuid=`pks cluster ${cluster_name} | grep UUID | cut -d':' -f2|awk '{$1=$1;print}'`
if [ -z "${cluster_uuid}" ]; then
    cluster_uuid=`pks create-cluster ${cluster_name} -p ${cluster_plan} -n ${cluster_workers} -e ${cluster_name}.${PROFILE}.${TLD} | grep UUID | cut -d':' -f2|awk '{$1=$1;print}'`
fi

echo
echo "cluster uuid: ${cluster_uuid}"

# get nautilus cluster master EC2 instance id
echo
echo "getting nautilus cluster master EC2 instance id"
while [ -z ${k8s_cluster_instance_id} ]
do
    echo "Trying to obtain ec2 instance id for cluster ${cluster_name}"
    sleep 30
    if [ -z "${k8s_cluster_instance_id}" ]; then
	    k8s_cluster_instance_id=(`aws ec2 describe-instances --region ${REGION} --filters Name=tag:"Name",Values=master/* Name=tag:"deployment",Values=service-instance_${cluster_uuid} --profile ${PROFILE} --output text --query 'Reservations[*].Instances[*].InstanceId'`)
    fi
done
echo "cluster ec2 instance id: ${k8s_cluster_instance_id}"

echo
echo "creating elb to access cluster master"
elb_output=`aws elbv2 create-load-balancer --name ${cluster_name}-${PROFILE} --type network --subnets ${SUBNET1} ${SUBNET2} --region ${REGION} --profile  ${PROFILE}`
if [ -z "${elb_output}" ]; then
    echo "setup elb to access your cluster, https://asdwiki.isus.emc.com:8443/display/NKB/Nautilus+OE+-+AWS+PKS+-+Installation+notes#NautilusOE-AWSPKS-Installationnotes-SetupNautilusprerequisitesonAWS"
    exit 1
fi
echo ${elb_output}

elb_dns_name=`echo $elb_output | jq -r '.LoadBalancers[0].DNSName'`
elb_arn=`echo $elb_output | jq -r '.LoadBalancers[0].LoadBalancerArn'`
elb_hosted_zone_id=`echo $elb_output | jq -r '.LoadBalancers[0].CanonicalHostedZoneId'`
echo
echo "created elb with dns name: ${elb_dns_name}, arn: ${elb_arn}, hosted zone id: ${elb_hosted_zone_id}"

echo
echo "creating elb target group"
elb_target_group_arn=`aws elbv2 create-target-group --name ${cluster_name}-targets --protocol TCP --port 8443 --vpc-id ${VPC_ID} --region ${REGION} --profile  ${PROFILE} | jq -r '.TargetGroups[0].TargetGroupArn'`
echo "created elb target group: ${elb_target_group_arn}"

echo
echo "register elb targets"

aws elbv2 register-targets --target-group-arn ${elb_target_group_arn} --targets ${k8s_cluster_instance_id[@]/#/Id=} --profile ${PROFILE} 

echo
echo "create elb listener"
aws elbv2 create-listener --load-balancer-arn ${elb_arn} --protocol TCP --port 8443 --default-actions Type=forward,TargetGroupArn=${elb_target_group_arn} --profile ${PROFILE}

#setup dns alias
cat <<EOF > /tmp/dns-record.json
{
    "Comment": "Creating Alias resource record sets in Route 53",
    "Changes": [{
        "Action": "CREATE",
        "ResourceRecordSet": {
            "Name": "${cluster_name}.${PROFILE}.${TLD}",
            "Type": "A",
            "AliasTarget":{
                "HostedZoneId": "${elb_hosted_zone_id}",
                "DNSName": "${elb_dns_name}",
                "EvaluateTargetHealth": false
            }
        }
    }]
}
EOF

echo
echo "setting up dns alias to access cluster ${cluster_name}"
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch file:///tmp/dns-record.json --profile ${PROFILE}

rm /tmp/dns-record.json
