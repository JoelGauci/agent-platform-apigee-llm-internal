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

# Exit immediately if any command returns a non-zero status
set -e

# Step 1: Load shared environment variables if present
if [ -f "./env.sh" ]; then
  source ./env.sh
fi

echo "===================================================================="
echo "Phase 2: Network Infrastructure & ILB + PSC Setup (02_network_setup.sh)"
echo "===================================================================="

# ====================================================================
# 1. Create VPC Networks (Consumer VPC & Producer VPC)
# ====================================================================
# Note: GCP Private Service Connect requires the Consumer Forwarding Rule
# and the Producer Service Attachment to be in different VPC networks.

# Check and create Consumer VPC network
if ! gcloud compute networks describe vnet-${SLUG} &>/dev/null; then
  echo "INFO: Creating Consumer VPC network vnet-${SLUG}..."
  gcloud compute networks create vnet-${SLUG} --subnet-mode=custom
else
  echo "INFO: Consumer VPC network vnet-${SLUG} already exists."
fi

# Check and create Producer VPC network
if ! gcloud compute networks describe vnet-${SLUG}-producer &>/dev/null; then
  echo "INFO: Creating Producer VPC network vnet-${SLUG}-producer..."
  gcloud compute networks create vnet-${SLUG}-producer --subnet-mode=custom
else
  echo "INFO: Producer VPC network vnet-${SLUG}-producer already exists."
fi

# ====================================================================
# 2. Create Custom Subnets
# ====================================================================

# Create Primary Subnet in Consumer VPC for Agent Gateway & PSC Endpoint
if ! gcloud compute networks subnets describe subnet-${REGION}-agw --region=${REGION} &>/dev/null; then
  echo "INFO: Creating subnet-${REGION}-agw in Consumer VPC..."
  gcloud compute networks subnets create subnet-${REGION}-agw \
    --network=vnet-${SLUG} \
    --range=192.168.10.0/28 \
    --region=${REGION} \
    --enable-private-ip-google-access
else
  echo "INFO: Subnet subnet-${REGION}-agw already exists."
fi

# Create Primary Subnet in Producer VPC for the Internal Load Balancer
if ! gcloud compute networks subnets describe subnet-${REGION}-producer-ilb --region=${REGION} &>/dev/null; then
  echo "INFO: Creating subnet-${REGION}-producer-ilb in Producer VPC..."
  gcloud compute networks subnets create subnet-${REGION}-producer-ilb \
    --network=vnet-${SLUG}-producer \
    --range=10.20.0.0/24 \
    --region=${REGION} \
    --enable-private-ip-google-access
else
  echo "INFO: Subnet subnet-${REGION}-producer-ilb already exists."
fi

# Create Regional Managed Proxy-Only Subnet in Producer VPC for Regional Envoy ILB
if ! gcloud compute networks subnets describe subnet-${REGION}-proxy --region=${REGION} &>/dev/null; then
  echo "INFO: Creating proxy subnet-${REGION}-proxy in Producer VPC..."
  gcloud compute networks subnets create subnet-${REGION}-proxy \
    --network=vnet-${SLUG}-producer \
    --range=10.9.0.0/24 \
    --region=${REGION} \
    --purpose=REGIONAL_MANAGED_PROXY \
    --role=ACTIVE
else
  echo "INFO: Proxy subnet subnet-${REGION}-proxy already exists."
fi

# Create PSC NAT Subnet in Producer VPC for the Service Attachment NAT pool
if ! gcloud compute networks subnets describe subnet-${REGION}-psc-nat --region=${REGION} &>/dev/null; then
  echo "INFO: Creating PSC NAT subnet-${REGION}-psc-nat in Producer VPC..."
  gcloud compute networks subnets create subnet-${REGION}-psc-nat \
    --network=vnet-${SLUG}-producer \
    --range=10.10.0.0/24 \
    --region=${REGION} \
    --purpose=PRIVATE_SERVICE_CONNECT
else
  echo "INFO: PSC NAT subnet subnet-${REGION}-psc-nat already exists."
fi

# ====================================================================
# 3. Create Firewall Policy & Rules
# ====================================================================

# Check and create Global Firewall Policy
if ! gcloud compute network-firewall-policies describe fw-policy-${SLUG} --global &>/dev/null; then
  echo "INFO: Creating global firewall policy fw-policy-${SLUG}..."
  gcloud compute network-firewall-policies create fw-policy-${SLUG} --global
else
  echo "INFO: Firewall policy fw-policy-${SLUG} already exists."
fi

# Add Egress rule 1001 allowing all egress traffic with logging enabled
if ! gcloud compute network-firewall-policies describe fw-policy-${SLUG} --global --format="value(rules[].priority)" 2>/dev/null | grep -q "1001"; then
  echo "INFO: Creating firewall policy rule 1001..."
  gcloud compute network-firewall-policies rules create 1001 \
    --description="allow all egress traffic and log" \
    --firewall-policy=fw-policy-${SLUG} \
    --global-firewall-policy \
    --action=allow \
    --direction=EGRESS \
    --layer4-configs=all \
    --dest-ip-ranges=0.0.0.0/0 \
    --enable-logging
else
  echo "INFO: Firewall policy rule 1001 already exists."
fi

# Bind Firewall Policy to Consumer VPC Network
if ! gcloud compute network-firewall-policies describe fw-policy-${SLUG} --global --format="value(associations[].name)" 2>/dev/null | grep -q "fw-policy-bind-${SLUG}-consumer"; then
  echo "INFO: Binding firewall policy to consumer network vnet-${SLUG}..."
  gcloud compute network-firewall-policies associations create \
    --name=fw-policy-bind-${SLUG}-consumer \
    --firewall-policy=fw-policy-${SLUG} \
    --network=vnet-${SLUG} \
    --global-firewall-policy
else
  echo "INFO: Firewall policy binding to consumer network already exists."
fi

# Bind Firewall Policy to Producer VPC Network
if ! gcloud compute network-firewall-policies describe fw-policy-${SLUG} --global --format="value(associations[].name)" 2>/dev/null | grep -q "fw-policy-bind-${SLUG}-producer"; then
  echo "INFO: Binding firewall policy to producer network vnet-${SLUG}-producer..."
  gcloud compute network-firewall-policies associations create \
    --name=fw-policy-bind-${SLUG}-producer \
    --firewall-policy=fw-policy-${SLUG} \
    --network=vnet-${SLUG}-producer \
    --global-firewall-policy
else
  echo "INFO: Firewall policy binding to producer network already exists."
fi

# ====================================================================
# 4. Create PSC Network Attachment (for Agent Gateway Egress in Consumer VPC)
# ====================================================================

# Create PSC Network Attachment in Consumer VPC
if ! gcloud compute network-attachments describe psc-na-${REGION}-agw --region=${REGION} &>/dev/null; then
  echo "INFO: Creating PSC network attachment psc-na-${REGION}-agw..."
  gcloud compute network-attachments create psc-na-${REGION}-agw \
    --region=${REGION} \
    --subnets=subnet-${REGION}-agw \
    --connection-preference=ACCEPT_AUTOMATIC
else
  echo "INFO: PSC network attachment psc-na-${REGION}-agw already exists."
fi

# Export selfLink URI of the PSC Network Attachment
export PSC_NA_URI=$(gcloud compute network-attachments describe psc-na-${REGION}-agw \
  --region=${REGION} \
  --format="value(selfLink.scope(v1))")
echo "INFO: PSC_NA_URI=${PSC_NA_URI}"

# ====================================================================
# 5. Internal Application Load Balancer (ILB) Components for Apigee X (in Producer VPC)
# ====================================================================

# Create Private Service Connect NEG targeting Apigee X Tenant Service Attachment
if ! gcloud compute network-endpoint-groups describe neg-apigee-psc --region=${REGION} &>/dev/null; then
  echo "INFO: Creating PSC NEG neg-apigee-psc..."
  if [[ "${APIGEE_SVC_ATTACHMENT}" == *"your-apigee-tp"* || -z "${APIGEE_SVC_ATTACHMENT}" ]]; then
    echo "ERROR: APIGEE_SVC_ATTACHMENT is not configured. Please set APIGEE_SVC_ATTACHMENT to your Apigee tenant Service Attachment URI in env.sh or .env"
    exit 1
  fi
  gcloud compute network-endpoint-groups create neg-apigee-psc \
    --network-endpoint-type=private-service-connect \
    --psc-target-service=${APIGEE_SVC_ATTACHMENT} \
    --network=vnet-${SLUG}-producer \
    --subnet=subnet-${REGION}-producer-ilb \
    --region=${REGION}
else
  echo "INFO: PSC NEG neg-apigee-psc already exists."
fi

# Create Regional HTTPS Backend Service for ILB
if ! gcloud compute backend-services describe backend-apigee-ilb --region=${REGION} &>/dev/null; then
  echo "INFO: Creating backend service backend-apigee-ilb..."
  gcloud compute backend-services create backend-apigee-ilb \
    --load-balancing-scheme=INTERNAL_MANAGED \
    --protocol=HTTPS \
    --region=${REGION}

  # Attach PSC NEG to the Backend Service
  gcloud compute backend-services add-backend backend-apigee-ilb \
    --network-endpoint-group=neg-apigee-psc \
    --network-endpoint-group-region=${REGION} \
    --region=${REGION}
else
  echo "INFO: Backend service backend-apigee-ilb already exists."
fi

# Create Certificate Manager DNS Authorization for Domain Ownership Verification
# NOTE: For the TLS handshake between the Vertex AI Agent Runtime container and the ILB
# to succeed, the certificate presented by the ILB must be issued by a trusted Certificate Authority (CA).
# This requires you to own a public DNS domain to provision a Google-managed certificate.
if ! gcloud certificate-manager dns-authorizations describe auth-apigee-iloveagents --location=${REGION} &>/dev/null; then
  echo "INFO: Creating Certificate Manager DNS authorization auth-apigee-iloveagents..."
  gcloud certificate-manager dns-authorizations create auth-apigee-iloveagents \
    --domain="apigee.iloveagents.io" \
    --location=${REGION}
else
  echo "INFO: Certificate Manager DNS authorization auth-apigee-iloveagents already exists."
fi

# Extract ACME challenge CNAME record details from DNS Authorization
export CNAME_NAME=$(gcloud certificate-manager dns-authorizations describe auth-apigee-iloveagents \
  --location=${REGION} \
  --format="value(dnsResourceRecord.name)")
export CNAME_DATA=$(gcloud certificate-manager dns-authorizations describe auth-apigee-iloveagents \
  --location=${REGION} \
  --format="value(dnsResourceRecord.data)")

echo "INFO: CNAME_NAME=${CNAME_NAME}"
echo "INFO: CNAME_DATA=${CNAME_DATA}"

# Ensure Public Cloud DNS Zone exists for Let's Encrypt / GTS ACME verification
if ! gcloud dns managed-zones describe pub-zone-iloveagents &>/dev/null; then
  echo "INFO: Creating public Cloud DNS zone pub-zone-iloveagents..."
  gcloud dns managed-zones create pub-zone-iloveagents \
    --dns-name="iloveagents.io." \
    --description="Public DNS zone for iloveagents.io" \
    --visibility=public 2>/dev/null || echo "INFO: Public DNS zone creation skipped or managed externally."
else
  echo "INFO: Public Cloud DNS zone pub-zone-iloveagents already exists."
fi

# Publish ACME challenge CNAME record to Public Cloud DNS
if gcloud dns managed-zones describe pub-zone-iloveagents &>/dev/null; then
  if ! gcloud dns record-sets describe "${CNAME_NAME}" --zone=pub-zone-iloveagents --type=CNAME &>/dev/null; then
    echo "INFO: Creating ACME CNAME record in public Cloud DNS zone..."
    gcloud dns record-sets create "${CNAME_NAME}" \
      --zone=pub-zone-iloveagents \
      --type=CNAME \
      --ttl=300 \
      --rrdatas="${CNAME_DATA}"
  else
    echo "INFO: ACME CNAME record already exists in public Cloud DNS."
  fi
else
  echo "WARNING: Public Cloud DNS zone 'pub-zone-iloveagents' not found. Please manually add CNAME record ${CNAME_NAME} -> ${CNAME_DATA}"
fi

# Create Certificate Manager Managed TLS Certificate
if ! gcloud certificate-manager certificates describe cert-apigee-ilb --location=${REGION} &>/dev/null; then
  echo "INFO: Creating Certificate Manager certificate cert-apigee-ilb..."
  gcloud certificate-manager certificates create cert-apigee-ilb \
    --domains="apigee.iloveagents.io" \
    --dns-authorizations=auth-apigee-iloveagents \
    --location=${REGION}
else
  echo "INFO: Certificate Manager certificate cert-apigee-ilb already exists."
fi

# Create Regional URL Map for routing requests to the Backend Service
if ! gcloud compute url-maps describe urlmap-apigee-ilb --region=${REGION} &>/dev/null; then
  echo "INFO: Creating URL map urlmap-apigee-ilb..."
  gcloud compute url-maps create urlmap-apigee-ilb \
    --default-service=backend-apigee-ilb \
    --region=${REGION}
else
  echo "INFO: URL map urlmap-apigee-ilb already exists."
fi

# Create Regional Target HTTPS Proxy with attached Certificate Manager Certificate
if ! gcloud compute target-https-proxies describe target-proxy-apigee-ilb --region=${REGION} &>/dev/null; then
  echo "INFO: Creating target HTTPS proxy target-proxy-apigee-ilb..."
  gcloud compute target-https-proxies create target-proxy-apigee-ilb \
    --url-map=urlmap-apigee-ilb \
    --certificate-manager-certificates=cert-apigee-ilb \
    --region=${REGION}
else
  echo "INFO: Target HTTPS proxy target-proxy-apigee-ilb already exists."
fi

# Set static IP address for the Producer ILB
export ILB_IP="10.20.0.5"
echo "INFO: ILB_IP=${ILB_IP}"

# Reserve Static Internal IPv4 Address for Producer ILB
if ! gcloud compute addresses describe ip-ilb-apigee --region=${REGION} &>/dev/null; then
  echo "INFO: Reserving internal IP ip-ilb-apigee (${ILB_IP})..."
  gcloud compute addresses create ip-ilb-apigee \
    --region=${REGION} \
    --subnet=subnet-${REGION}-producer-ilb \
    --addresses=${ILB_IP}
else
  echo "INFO: Reserved IP ip-ilb-apigee already exists."
fi

# Create Internal Forwarding Rule for Producer ILB on port 443
if ! gcloud compute forwarding-rules describe forwarding-rule-apigee-ilb --region=${REGION} &>/dev/null; then
  echo "INFO: Creating ILB forwarding rule forwarding-rule-apigee-ilb..."
  gcloud compute forwarding-rules create forwarding-rule-apigee-ilb \
    --load-balancing-scheme=INTERNAL_MANAGED \
    --network=vnet-${SLUG}-producer \
    --subnet=subnet-${REGION}-producer-ilb \
    --address=ip-ilb-apigee \
    --ports=443 \
    --target-https-proxy=target-proxy-apigee-ilb \
    --target-https-proxy-region=${REGION} \
    --region=${REGION}
else
  echo "INFO: ILB forwarding rule forwarding-rule-apigee-ilb already exists."
fi

# ====================================================================
# 6. Create Service Attachment for the ILB in Producer VPC
# ====================================================================

# Publish Service Attachment exposing the ILB across VPC networks via PSC
if ! gcloud compute service-attachments describe sa-apigee-ilb --region=${REGION} &>/dev/null; then
  echo "INFO: Creating Service Attachment sa-apigee-ilb..."
  gcloud compute service-attachments create sa-apigee-ilb \
    --region=${REGION} \
    --producer-forwarding-rule=forwarding-rule-apigee-ilb \
    --connection-preference=ACCEPT_AUTOMATIC \
    --nat-subnets=subnet-${REGION}-psc-nat
else
  echo "INFO: Service Attachment sa-apigee-ilb already exists."
fi

# Retrieve full URI of the Service Attachment
export ILB_SA_URI=$(gcloud compute service-attachments describe sa-apigee-ilb \
  --region=${REGION} \
  --format="value(selfLink.scope(v1))")
echo "INFO: ILB_SA_URI=${ILB_SA_URI}"

# ====================================================================
# 7. Create PSC Endpoint connecting Consumer VPC to the ILB Service Attachment
# ====================================================================

# Set static IP address for Consumer PSC Endpoint (must be inside subnet-us-central1-agw range .4 - .14)
export PSC_EP_IP="192.168.10.4"
echo "INFO: PSC_EP_IP=${PSC_EP_IP}"

# Reserve Static Internal IPv4 Address for Consumer PSC Endpoint
if ! gcloud compute addresses describe ip-psc2apigeex --region=${REGION} &>/dev/null; then
  echo "INFO: Reserving PSC endpoint IP ip-psc2apigeex (${PSC_EP_IP})..."
  gcloud compute addresses create ip-psc2apigeex \
    --region=${REGION} \
    --subnet=subnet-${REGION}-agw \
    --addresses=${PSC_EP_IP}
else
  echo "INFO: PSC endpoint IP ip-psc2apigeex already exists."
fi

# Create Consumer PSC Forwarding Rule pointing to Producer Service Attachment
if ! gcloud compute forwarding-rules describe psc2apigeex --region=${REGION} &>/dev/null; then
  echo "INFO: Creating PSC endpoint forwarding rule psc2apigeex in Consumer VPC..."
  gcloud compute forwarding-rules create psc2apigeex \
    --region=${REGION} \
    --network=vnet-${SLUG} \
    --address=ip-psc2apigeex \
    --target-service-attachment=${ILB_SA_URI}
else
  echo "INFO: PSC endpoint forwarding rule psc2apigeex already exists."
fi

# Describe Forwarding Rule status
gcloud compute forwarding-rules describe psc2apigeex --region=${REGION}

# ====================================================================
# 8. Create Private DNS Zone, A Record, and Logging Policy in Consumer VPC
# ====================================================================

# Create Private DNS Zone bound to Consumer VPC
if ! gcloud dns managed-zones describe priv-zone-run &>/dev/null; then
  echo "INFO: Creating private DNS zone priv-zone-run in Consumer VPC..."
  gcloud dns managed-zones create priv-zone-run \
    --description="private zone apigee instance" \
    --dns-name="iloveagents.io." \
    --visibility=private \
    --networks=vnet-${SLUG}
else
  echo "INFO: Private DNS zone priv-zone-run already exists."
fi

# Create Private DNS A Record mapping apigee.iloveagents.io to PSC Endpoint IP
if ! gcloud dns record-sets describe apigee.iloveagents.io --zone=priv-zone-run --type=A &>/dev/null; then
  echo "INFO: Creating A record apigee.iloveagents.io (${PSC_EP_IP}) in private DNS zone..."
  gcloud dns record-sets create apigee.iloveagents.io \
    --zone=priv-zone-run \
    --type=A \
    --ttl=300 \
    --rrdatas=${PSC_EP_IP}
else
  echo "INFO: Private DNS A record apigee.iloveagents.io already exists."
fi

# Create DNS Logging Policy bound to Consumer VPC
if ! gcloud dns policies describe dns-policy-${SLUG} &>/dev/null; then
  echo "INFO: Creating DNS logging policy dns-policy-${SLUG}..."
  gcloud dns policies create dns-policy-${SLUG} \
    --description="dns logging for vnet-${SLUG}" \
    --networks=vnet-${SLUG} \
    --enable-logging
else
  echo "INFO: DNS logging policy dns-policy-${SLUG} already exists."
fi

echo "INFO: Phase 2 Network & ILB + PSC Setup completed successfully."
