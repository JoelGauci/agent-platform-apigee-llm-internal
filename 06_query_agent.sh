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

# Step 1: Load shared environment variables if present
if [ -f "./env.sh" ]; then
  source ./env.sh
fi

# Step 2: Load Reasoning Engine environment file if present
if [ -f "./cfg/reasoning_engine.env" ]; then
  source ./cfg/reasoning_engine.env
elif [ -f "./agent_apigee/cfg/reasoning_engine.env" ]; then
  source ./agent_apigee/cfg/reasoning_engine.env
fi

# Step 3: Ensure PATH includes uv
export PATH="$HOME/.local/bin:$PATH"

# Prompt to send (default if not passed as argument)
PROMPT="${1:-Hello! Please introduce yourself briefly.}"

echo "===================================================================="
echo "Phase 6: Send Query to Agent Runtime (06_query_agent.sh)"
echo "===================================================================="
echo "INFO: Target Prompt: \"${PROMPT}\""

if [ -z "$RE_ENGINE_ID" ]; then
  echo "ERROR: Active Reasoning Engine ID not found. Run ./05_deploy_agent_runtime.sh first."
  exit 1
fi

echo "INFO: Target Reasoning Engine ID: ${RE_ENGINE_ID}"

# Step 4: Query using Python Vertex AI SDK
echo "--------------------------------------------------------------------"
echo "Method 1: Querying via Python Vertex AI SDK (uv)..."
echo "--------------------------------------------------------------------"
if command -v uv &>/dev/null; then
  uv --directory agent_apigee run python3 -c "
import vertexai
from vertexai.preview import reasoning_engines

vertexai.init(project='${PROJ_ID}', location='${REGION}')
engine = reasoning_engines.ReasoningEngine('projects/${PROJ_ID}/locations/${REGION}/reasoningEngines/${RE_ENGINE_ID}')
response = engine.query(prompt='''${PROMPT}''')
print('RESPONSE:', response)
"
fi

# Step 5: Query using REST API (curl)
echo "--------------------------------------------------------------------"
echo "Method 2: Querying via REST API (curl)..."
echo "--------------------------------------------------------------------"
curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "{
    \"class_method\": \"query\",
    \"input\": {
      \"prompt\": \"${PROMPT}\"
    }
  }" \
  "https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJ_ID}/locations/${REGION}/reasoningEngines/${RE_ENGINE_ID}:query" | jq .

echo ""
echo "INFO: Phase 6 Query completed."
