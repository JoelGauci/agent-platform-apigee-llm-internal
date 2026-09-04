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

# Exit immediately if any phase script fails
set -e

# Step 1: Load shared environment variables if present
if [ -f "./env.sh" ]; then
  source ./env.sh
fi

echo "===================================================================="
echo "Starting Main Orchestrator: Agent Gateway & Apigee X Internal Setup"
echo "===================================================================="

# Step 2: Execute Phase 1 Initial Setup & API enablement
if [ -x "./01_initial_setup.sh" ]; then
  echo "INFO: Running Phase 1 (01_initial_setup.sh)..."
  ./01_initial_setup.sh
fi

# Step 3: Execute Phase 2 Multi-VPC Network & ILB + PSC Setup
if [ -x "./02_network_setup.sh" ]; then
  echo "INFO: Running Phase 2 (02_network_setup.sh)..."
  ./02_network_setup.sh
fi

# Step 4: Execute Phase 3 Agent Gateway Setup
if [ -x "./03_agent_gateway_setup.sh" ]; then
  echo "INFO: Running Phase 3 (03_agent_gateway_setup.sh)..."
  ./03_agent_gateway_setup.sh
fi

# Step 5: Execute Phase 4 Agent Registry Setup
if [ -x "./04_agent_registry_setup.sh" ]; then
  echo "INFO: Running Phase 4 (04_agent_registry_setup.sh)..."
  ./04_agent_registry_setup.sh
fi

# Step 6: Execute Phase 5 Agent Runtime Deployment
if [ -x "./05_deploy_agent_runtime.sh" ]; then
  echo "INFO: Running Phase 5 (05_deploy_agent_runtime.sh)..."
  ./05_deploy_agent_runtime.sh
fi

echo "===================================================================="
echo "SUCCESS: Agent Gateway & Apigee X Internal Setup Completed!"
echo "===================================================================="
