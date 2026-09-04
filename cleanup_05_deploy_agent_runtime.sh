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
echo "Cleanup Phase 5: Agent Runtime Cleanup (cleanup_05_deploy_agent_runtime.sh)"
echo "===================================================================="

# Fetch Reasoning Engine resource ID
export RE_ENGINE_ID=$(curl -s -X GET "https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJ_ID}/locations/${REGION}/reasoningEngines" \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" | \
  jq -r --arg name "${RE_AGENT_NAME}" '.reasoningEngines[]? | select(.displayName==$name) | .name | split("/") | last' 2>/dev/null || echo "")

if [ -n "$RE_ENGINE_ID" ]; then
  echo "INFO: Deleting Reasoning Engine ${RE_ENGINE_ID}..."
  curl -s -X DELETE "https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJ_ID}/locations/${REGION}/reasoningEngines/${RE_ENGINE_ID}" \
    -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" || true
else
  echo "INFO: Reasoning Engine '${RE_AGENT_NAME}' not found, skipping cleanup."
fi

echo "INFO: Cleanup Phase 5 completed successfully."
