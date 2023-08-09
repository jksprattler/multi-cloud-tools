#!/usr/bin/env bash
# Jenna Sprattler | SRE Kentik | 2023-08-09
# Checks to see which cloud provider and region this script is running in
# Supported CSP's: azure, gcp, aws, alibabacloud, vultr/choopa, digitalocean
# tencentcloud, exoscale, ibmcloud

set -e pipefail

function main() {
    if metadata=$(curl --fail -s -m 3 -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2017-08-01") && [[ $metadata ]]; then
        echo "CSP: azure"
        region=$(echo "$metadata" | jq -r '.compute.location')
        echo "Region: $region"
    elif metadata=$(curl --fail -s -m 3 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone); then
        echo "CSP: gcp"
        region=$(echo "$metadata" | cut -d "/" -f 4)
        echo "Region: $region"
    elif [[ $(curl --fail -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -e '.accountId' 2>/dev/null) ]]; then
        echo "CSP: aws_imdsv1"
        region=$(curl --fail -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
        echo "Region: $region"
    elif TOKEN=$(curl --fail -s -m 3 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 600") \
        && [[ $(curl --fail -s -m 3 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | \
        jq -e 'has("accountId")' 2>/dev/null) ]]; then
        echo "CSP: aws_imdsv2"
        region=$(curl --fail -s -m 3 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | \
        jq -r '.region')
        echo "Region: $region"
    elif TOKEN=$(curl --fail -s -m 3 -X PUT "http://100.100.100.200/latest/api/token" -H "X-aliyun-ecs-metadata-token-ttl-seconds: 600") \
        && region=$(curl --fail -s -m 3 http://100.100.100.200/latest/meta-data/region-id); then
        echo "CSP: alibabacloud"
        echo "Region: $region"
    elif [[ $(curl --fail -s -m 3 http://169.254.169.254/v1.json | jq -e 'has("nvidia-driver")' 2>/dev/null) ]]; then
        echo "CSP: vultr/choopa"
        region=$(curl --fail -s -m 3 http://169.254.169.254/v1.json | jq -r '.region.regioncode + " " + .region.countrycode')
        echo "Region: $region"
    elif [[ $(curl --fail -s -m 3 http://169.254.169.254/metadata/v1.json | jq -e 'has("droplet_id")' 2>/dev/null) ]]; then
        echo "CSP: digitalocean"
        region=$(curl --fail -s -m 3 http://169.254.169.254/metadata/v1/region)
        echo "Region: $region"
    elif curl --fail -s -m 3 http://metadata.tencentyun.com/latest/meta-data/ > /dev/null 2>&1; then
        echo "CSP: tencentcloud"
        region=$(curl --fail -s -m 3 http://metadata.tencentyun.com/latest/meta-data/placement/region)
        echo "Region: $region"
    elif metadata=$(curl --fail -s -m 3 http://169.254.169.254/1.0/meta-data/cloud-identifier | grep -e "Exoscale" 2>/dev/null) && [[ $metadata ]]; then
        echo "CSP: exoscale"
        region=$(curl --fail -s -m 3 http://169.254.169.254/1.0/meta-data/availability-zone)
        echo "Region: $region"
    elif TOKEN=$(curl --fail -s -m 3 -X PUT "http://169.254.169.254/instance_identity/v1/token?version=2022-03-01" -H "Metadata-Flavor: ibm" \
        -H "Accept: application/json"\
        -d '{
                "expires_in": 600
            }' | jq -r '(.access_token)') \
        && metadata=$(curl --fail -s -m 3 -X GET "http://169.254.169.254/metadata/v1/instance/initialization?version=2022-03-01" \
        -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" | jq -r) && [[ $metadata ]]; then
        echo "CSP: ibmcloud"
        region=$(curl --fail -s -m 3 -X GET "http://169.254.169.254/metadata/v1/instance?version=2022-03-01" \
        -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" | jq -r '.zone.name')
        echo "Region: $region"
    else
        echo "unknown: metadata unavailable"
    fi
}

main
