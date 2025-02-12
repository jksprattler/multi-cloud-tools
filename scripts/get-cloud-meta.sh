#!/usr/bin/env bash
# Jenna Sprattler | SRE Kentik | 2023-08-09
# Outputs the cloud service provider, region, machine type and public ipv4/6 address of the vm
# Supported CSP's: azure, gcp, aws, alibabacloud, linode, vultr/choopa, digitalocean, tencentcloud,
# exoscale, ibmcloud, oci

pipv4=$(curl -4 -s ifconfig.me)
pipv6=$(curl -6 -s ifconfig.me)
fqdn=$(hostname -f)

function main() {
    if metadata=$(curl --fail -s -m 3 -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2017-08-01") && [[ $metadata ]]; then
        echo -e "CSP:\tazure"
        region=$(echo "$metadata" | jq -r '.compute.location')
        echo -e "Region:\t$region"
        type=$(echo "$metadata" | jq -r '.compute.vmSize')
        echo -e "Type:\t$type"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
        echo -e "Fqdn:\t$fqdn."
    elif metadata=$(curl --fail -s -m 3 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone) && [[ $metadata ]]; then
        echo -e "CSP:\tgcp"
        region=$(echo "$metadata" | cut -d "/" -f 4)
        echo -e "Region:\t$region"
        type=$(curl --fail -s -m 3 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/machine-type | cut -d "/" -f 4)
        echo -e "Type:\t$type"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
        echo -e "Fqdn:\t$fqdn."
    elif [[ $(curl --fail -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -e '.accountId' 2>/dev/null) ]]; then
        echo -e "CSP:\taws_imdsv1"
        region=$(curl --fail -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
        echo -e "Region:\t$region"
        type=$(curl --fail -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.instanceType')
        echo -e "Type:\t$type"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
    elif TOKEN=$(curl --fail -s -m 3 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 600") &&
        [[ $(curl --fail -s -m 3 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document |
            jq -e 'has("accountId")' 2>/dev/null) ]]; then
        echo -e "CSP:\taws_imdsv2"
        region=$(curl --fail -s -m 3 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document |
            jq -r '.region')
        echo -e "Region:\t$region"
        type=$(curl --fail -s -m 3 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document |
            jq -r '.instanceType')
        echo -e "Type:\t$type"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
    elif TOKEN=$(curl --fail -s -m 3 -X PUT "http://100.100.100.200/latest/api/token" -H "X-aliyun-ecs-metadata-token-ttl-seconds: 600") &&
        region=$(curl --fail -s -m 3 http://100.100.100.200/latest/meta-data/region-id); then
        echo -e "CSP:\talibabacloud"
        echo -e "Region:\t$region"
        type=$(curl --fail -s -m 3 http://100.100.100.200/latest/meta-data/instance/instance-type)
        echo -e "Type:\t$type"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
        echo -e "Fqdn:\t$fqdn."
    elif TOKEN=$(curl --fail -s -m 3 -X PUT -H "Metadata-Token-Expiry-Seconds: 3600" http://169.254.169.254/v1/token) &&
        metadata=$(curl --fail -s -m 3 -H "Metadata-Token: $TOKEN" http://169.254.169.254/v1/instance | grep -e "linode" 2>/dev/null); then
        echo -e "CSP:\tlinode"
        region=$(curl --fail -s -m 3 -H "Metadata-Token: $TOKEN" http://169.254.169.254/v1/instance | awk -F": " '/region/ {print $2}')
        echo -e "Region:\t$region"
        type=$(curl --fail -s -m 3 -H "Metadata-Token: $TOKEN" http://169.254.169.254/v1/instance | awk -F": " '/type/ {print $2}')
        echo -e "Type:\t$type"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
        echo -e "Fqdn:\t$fqdn."
    elif [[ $(curl --fail -s -m 3 http://169.254.169.254/v1.json | jq -e 'has("nvidia-driver")' 2>/dev/null) ]]; then
        echo -e "CSP:\tvultr/choopa"
        region=$(curl --fail -s -m 3 http://169.254.169.254/v1.json | jq -r '.region.regioncode + " " + .region.countrycode')
        echo -e "Region:\t$region"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
        echo -e "Fqdn:\t$fqdn."
    elif [[ $(curl --fail -s -m 3 http://169.254.169.254/metadata/v1.json | jq -e 'has("droplet_id")' 2>/dev/null) ]]; then
        echo -e "CSP:\tdigitalocean"
        region=$(curl --fail -s -m 3 http://169.254.169.254/metadata/v1/region)
        echo -e "Region:\t$region"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
        echo -e "Fqdn:\t$fqdn."
    elif metadata=$(curl --fail -s -m 3 http://metadata.tencentyun.com/latest/meta-data) && [[ $metadata ]]; then
        echo -e "CSP:\ttencentcloud"
        region=$(curl --fail -s -m 3 http://metadata.tencentyun.com/latest/meta-data/placement/region)
        echo -e "Region:\t$region"
        type=$(curl --fail -s -m 3 http://metadata.tencentyun.com/latest/meta-data/instance/instance-type)
        echo -e "Type:\t$type"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
        echo -e "Fqdn:\t$fqdn."
    elif metadata=$(curl --fail -s -m 3 http://169.254.169.254/1.0/meta-data/cloud-identifier | grep -e "Exoscale" 2>/dev/null) && [[ $metadata ]]; then
        echo -e "CSP:\texoscale"
        region=$(curl --fail -s -m 3 http://169.254.169.254/1.0/meta-data/availability-zone)
        echo -e "Region:\t$region"
        type=$(curl --fail -s -m 3 http://169.254.169.254/1.0/meta-data/service-offering)
        echo -e "Type:\t$type"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
        echo -e "Fqdn:\t$fqdn."
    elif TOKEN=$(curl --fail -s -m 3 -X PUT "http://169.254.169.254/instance_identity/v1/token?version=2022-03-01" -H "Metadata-Flavor: ibm" \
        -H "Accept: application/json" \
        -d '{
                "expires_in": 600
            }' | jq -r '(.access_token)') &&
        metadata=$(curl --fail -s -m 3 -X GET "http://169.254.169.254/metadata/v1/instance/initialization?version=2022-03-01" \
            -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" | jq -r) && [[ $metadata ]]; then
        echo -e "CSP:\tibmcloud"
        region=$(curl --fail -s -m 3 -X GET "http://169.254.169.254/metadata/v1/instance?version=2022-03-01" \
            -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" | jq -r '.zone.name')
        echo -e "Region:\t$region"
        type=$(curl --fail -s -m 3 -X GET "http://169.254.169.254/metadata/v1/instance?version=2022-03-01" \
            -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" | jq -r '.profile.name')
        echo -e "Type:\t$type"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
        echo -e "Fqdn:\t$fqdn."
    elif metadata=$(curl --fail -s -m 3 -H "Metadata:true" "http://169.254.169.254/opc/v1/instance") && [[ $metadata ]]; then
        echo -e "CSP:\toci"
        region=$(echo "$metadata" | jq -r '.regionInfo.regionIdentifier')
        echo -e "Region:\t$region"
        type=$(echo "$metadata" | jq -r '.shape')
        echo -e "Type:\t$type"
        echo -e "Pipv4:\t$pipv4"
        echo -e "Pipv6:\t$pipv6"
        echo -e "Fqdn:\t$fqdn."
    else
        echo "unknown: metadata unavailable"
    fi
}

main
