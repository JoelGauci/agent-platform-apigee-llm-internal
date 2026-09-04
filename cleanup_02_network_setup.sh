#!/bin/bash

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# Load shared environment variables
if [ -f "./env.sh" ]; then
  source ./env.sh
fi

echo "===================================================================="
echo "Cleanup Phase 2: Network Infrastructure & ILB Cleanup (cleanup_02_network_setup.sh)"
echo "===================================================================="

# Delete DNS policy
gcloud dns policies delete dns-policy-${SLUG} --quiet || true

# Delete DNS record-set
gcloud dns record-sets delete apigee.iloveagents.io --zone=priv-zone-run --type=A --quiet || true

# Delete DNS managed-zone
gcloud dns managed-zones delete priv-zone-run --quiet || true

# Delete PSC forwarding rule connecting to ILB Service Attachment
gcloud compute forwarding-rules delete psc2apigeex --region=${REGION} --quiet || true

# Delete reserved internal IP address for PSC endpoint
gcloud compute addresses delete ip-psc2apigeex --region=${REGION} --quiet || true

# Delete Service Attachment for ILB
gcloud compute service-attachments delete sa-apigee-ilb --region=${REGION} --quiet || true

# Delete ILB Forwarding Rule
gcloud compute forwarding-rules delete forwarding-rule-apigee-ilb --region=${REGION} --quiet || true

# Delete Reserved IP for ILB
gcloud compute addresses delete ip-ilb-apigee --region=${REGION} --quiet || true

# Delete Target HTTPS Proxy
gcloud compute target-https-proxies delete target-proxy-apigee-ilb --region=${REGION} --quiet || true

# Delete URL Map
gcloud compute url-maps delete urlmap-apigee-ilb --region=${REGION} --quiet || true

# Delete Certificate Manager Certificate
gcloud certificate-manager certificates delete cert-apigee-ilb --location=${REGION} --quiet || true

# Delete ACME CNAME record from Public Cloud DNS Zone
if [ -n "$CNAME_NAME" ]; then
  gcloud dns record-sets delete "${CNAME_NAME}" --zone=pub-zone-iloveagents --type=CNAME --quiet || true
fi

# Delete Certificate Manager DNS Authorization
gcloud certificate-manager dns-authorizations delete auth-apigee-iloveagents --location=${REGION} --quiet || true

# Delete Backend Service
gcloud compute backend-services delete backend-apigee-ilb --region=${REGION} --quiet || true

# Delete PSC NEG
gcloud compute network-endpoint-groups delete neg-apigee-psc --region=${REGION} --quiet || true

# Delete PSC Network Attachment (for Agent Gateway)
gcloud compute network-attachments delete psc-na-${REGION}-agw --region=${REGION} --quiet || true

# Delete Firewall Policy Associations
gcloud compute network-firewall-policies associations delete \
  --name=fw-policy-bind-${SLUG}-consumer \
  --firewall-policy=fw-policy-${SLUG} \
  --global-firewall-policy --quiet || true

gcloud compute network-firewall-policies associations delete \
  --name=fw-policy-bind-${SLUG}-producer \
  --firewall-policy=fw-policy-${SLUG} \
  --global-firewall-policy --quiet || true

# Delete Firewall Policy
gcloud compute network-firewall-policies delete fw-policy-${SLUG} --global --quiet || true

# Delete Subnets
gcloud compute networks subnets delete subnet-${REGION}-psc-nat --region=${REGION} --quiet || true
gcloud compute networks subnets delete subnet-${REGION}-proxy --region=${REGION} --quiet || true
gcloud compute networks subnets delete subnet-${REGION}-producer-ilb --region=${REGION} --quiet || true
gcloud compute networks subnets delete subnet-${REGION}-agw --region=${REGION} --quiet || true

# Delete VPC Networks
gcloud compute networks delete vnet-${SLUG}-producer --quiet || true
gcloud compute networks delete vnet-${SLUG} --quiet || true

echo "INFO: Cleanup Phase 2 completed successfully."
