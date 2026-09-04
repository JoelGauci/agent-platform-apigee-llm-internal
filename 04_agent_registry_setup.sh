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
echo "Phase 4: Agent Registry Setup (04_agent_registry_setup.sh)"
echo "===================================================================="

# Step 2: Check and create core Google API endpoint service in Agent Registry if not already registered
if ! gcloud agent-registry services describe core-gapi-services --location=${REGION} &>/dev/null; then
  echo "INFO: Creating Agent Registry service core-gapi-services..."
  gcloud agent-registry services create core-gapi-services \
    --location=${REGION} \
    --display-name="gapi.core.services" \
    --description="core apis and services" \
    --endpoint-spec-type=no-spec \
    --interfaces=protocolBinding=JSONRPC,url=https://telemetry.googleapis.com \
    --interfaces=protocolBinding=JSONRPC,url=https://${REGION}-aiplatform.googleapis.com \
    --interfaces=protocolBinding=JSONRPC,url=https://cloudresourcemanager.googleapis.com \
    --interfaces=protocolBinding=JSONRPC,url=https://iamcredentials.googleapis.com 2>/dev/null || echo "INFO: Core Google API URLs are already registered under existing Agent Registry services."
else
  echo "INFO: Agent Registry service core-gapi-services already exists."
fi

# Step 3: Check and create Apigee X internal endpoint service in Agent Registry if not existing
if ! gcloud agent-registry services describe apigeex --location=${REGION} &>/dev/null; then
  echo "INFO: Creating Agent Registry service apigeex..."
  gcloud agent-registry services create apigeex \
    --location=${REGION} \
    --display-name="apigeex" \
    --description="Apigee X internal endpoint" \
    --endpoint-spec-type=no-spec \
    --interfaces=protocolBinding=JSONRPC,url=https://apigee.iloveagents.io
else
  echo "INFO: Agent Registry service apigeex already exists."
fi

# Step 4: List registered regional endpoints formatted in table format
gcloud agent-registry endpoints list --location=${REGION} \
  --flatten="interfaces[]" \
  --format="table(displayName, name.basename():label=ENDPOINT_ID, interfaces.url:label=URL)"
