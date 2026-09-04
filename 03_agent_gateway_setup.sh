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
echo "Phase 3: Agent Gateway Setup (03_agent_gateway_setup.sh)"
echo "===================================================================="

# Step 2: Ensure local config directory exists for storing YAML files
mkdir -p cfg

# Step 3: Re-fetch PSC_NA_URI from GCP if not already set in environment
if [ -z "$PSC_NA_URI" ]; then
  export PSC_NA_URI=$(gcloud compute network-attachments describe psc-na-${REGION}-agw \
    --region=${REGION} \
    --format="value(selfLink.scope(v1))" 2>/dev/null || echo "")
fi

# Step 4: Generate Agent Gateway network configuration YAML file supporting MCP, HTTP, and HTTPS protocols
cat > cfg/${AGW_NAME}-networkConfig.yaml << EOF
name: ${AGW_NAME}
protocols:
  - MCP
  - HTTP
  - HTTPS
googleManaged:
  governedAccessPath: AGENT_TO_ANYWHERE
registries:
  - "//agentregistry.googleapis.com/projects/${PROJ_ID}/locations/${REGION}"
networkConfig:
  egress:
    networkAttachment: ${PSC_NA_URI}
  dnsPeeringConfig:
    domains:
      - iloveagents.io.
    targetProject: ${PROJ_ID}
    targetNetwork: projects/${PROJ_ID}/global/networks/vnet-${SLUG}
EOF

# Step 5: Import/Update Agent Gateway configuration
echo "INFO: Importing/Updating Agent Gateway ${AGW_NAME} configuration..."
gcloud network-services agent-gateways import ${AGW_NAME} \
  --source="cfg/${AGW_NAME}-networkConfig.yaml" \
  --location=${REGION}

# Step 6: Describe Agent Gateway resource configuration
gcloud network-services agent-gateways describe ${AGW_NAME} \
  --location=${REGION}

# Step 7: Describe PSC Network Attachment details
gcloud compute network-attachments describe psc-na-${REGION}-agw --region=${REGION}
