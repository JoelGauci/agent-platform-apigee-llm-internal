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
echo "Cleanup Phase 3: Agent Gateway Cleanup (cleanup_03_agent_gateway_setup.sh)"
echo "===================================================================="

# Delete Agent Gateway
gcloud network-services agent-gateways delete ${AGW_NAME} --location=${REGION} --quiet || true

# Remove generated networkConfig yaml file
if [ -f "cfg/${AGW_NAME}-networkConfig.yaml" ]; then
  rm -f "cfg/${AGW_NAME}-networkConfig.yaml"
  echo "INFO: Removed cfg/${AGW_NAME}-networkConfig.yaml"
fi

echo "INFO: Cleanup Phase 3 completed successfully."
