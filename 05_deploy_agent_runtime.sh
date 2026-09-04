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

# Step 2: Load Reasoning Engine environment file if present
if [ -f "./cfg/reasoning_engine.env" ]; then
  source ./cfg/reasoning_engine.env
fi

# Step 3: Ensure PATH includes user local bin for uv tool
export PATH="$HOME/.local/bin:$PATH"

echo "===================================================================="
echo "Phase 5: Deploy ADK ApigeeLLM Agent to Agent Runtime (05_deploy_agent_runtime.sh)"
echo "===================================================================="

# Step 4: Ensure GCS Staging Bucket exists for Agent Runtime code artifacts
if ! gcloud storage buckets describe "gs://${STAGING_BUCKET}" &>/dev/null; then
  echo "INFO: Creating GCS staging bucket gs://${STAGING_BUCKET}..."
  gcloud storage buckets create "gs://${STAGING_BUCKET}" --location=${REGION}
else
  echo "INFO: GCS staging bucket gs://${STAGING_BUCKET} already exists."
fi

# Step 5: Re-fetch AGW_URI if not already set in environment
if [ -z "$AGW_URI" ]; then
  export AGW_URI="projects/${PROJ_ID}/locations/${REGION}/agentGateways/${AGW_NAME}"
fi

# Step 6: Check if Reasoning Engine resource already exists on Agent Runtime
RE_EXISTS=false
if [ -n "$RE_ENGINE_ID" ]; then
  if curl -s -X GET "https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJ_ID}/locations/${REGION}/reasoningEngines/${RE_ENGINE_ID}" \
    -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" | jq -e '.name' &>/dev/null; then
    RE_EXISTS=true
  fi
fi

if [ "$RE_EXISTS" = true ]; then
  echo "INFO: Agent Runtime Reasoning Engine '${RE_AGENT_NAME}' already exists (ID: ${RE_ENGINE_ID}), skipping deployment."
else
  echo "INFO: Deploying Agent Runtime Reasoning Engine '${RE_AGENT_NAME}'..."
  if command -v uv &>/dev/null; then
    echo "INFO: Executing deployment script using uv package runner in agent_apigee directory..."
    uv --directory agent_apigee run python3 deploy_agent.py \
      --project=${PROJ_ID} \
      --region=${REGION} \
      --staging-bucket=${STAGING_BUCKET} \
      --display-name="${RE_AGENT_NAME}" \
      --agent-gateway-egress=${AGW_URI} \
      --apigee-hostname="${APIGEE_HOSTNAME}" \
      --apigee-llm="${APIGEE_LLM}" \
      --apikey="${APIGEE_APIKEY}" \
      --model-name="${MODEL_NAME}"
  else
    echo "INFO: Executing deployment script using standard python3..."
    python3 agent_apigee/deploy_agent.py \
      --project=${PROJ_ID} \
      --region=${REGION} \
      --staging-bucket=${STAGING_BUCKET} \
      --display-name="${RE_AGENT_NAME}" \
      --agent-gateway-egress=${AGW_URI} \
      --apigee-hostname="${APIGEE_HOSTNAME}" \
      --apigee-llm="${APIGEE_LLM}" \
      --apikey="${APIGEE_APIKEY}" \
      --model-name="${MODEL_NAME}"
  fi
fi

# Reload environment after deployment
if [ -f "./cfg/reasoning_engine.env" ]; then
  source ./cfg/reasoning_engine.env
elif [ -f "./agent_apigee/cfg/reasoning_engine.env" ]; then
  source ./agent_apigee/cfg/reasoning_engine.env
fi

# Step 7: Query and display deployment details from Vertex AI API
if [ -n "$RE_ENGINE_ID" ]; then
  echo "INFO: Fetching Agent Runtime resource details..."
  curl -s -X GET "https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJ_ID}/locations/${REGION}/reasoningEngines/${RE_ENGINE_ID}" \
    -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" | \
    jq '{displayName: .displayName, name: .name, effectiveIdentity: .spec.effectiveIdentity, agentGatewayConfig: .spec.deploymentSpec.agentGatewayConfig}'
fi

echo "INFO: Phase 5 Agent Runtime Deployment completed successfully."
