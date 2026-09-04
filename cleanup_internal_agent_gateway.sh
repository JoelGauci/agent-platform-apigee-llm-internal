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
echo "Starting Main Cleanup Orchestrator: Agent Gateway & Apigee X Internal"
echo "===================================================================="

# Cleanup Phase 5: Agent Runtime Deployment
if [ -x "./cleanup_05_deploy_agent_runtime.sh" ]; then
  ./cleanup_05_deploy_agent_runtime.sh
fi

# Cleanup Phase 4: Agent Registry Setup
if [ -x "./cleanup_04_agent_registry_setup.sh" ]; then
  ./cleanup_04_agent_registry_setup.sh
fi

# Cleanup Phase 3: Agent Gateway Setup
if [ -x "./cleanup_03_agent_gateway_setup.sh" ]; then
  ./cleanup_03_agent_gateway_setup.sh
fi

# Cleanup Phase 2: Network Setup
if [ -x "./cleanup_02_network_setup.sh" ]; then
  ./cleanup_02_network_setup.sh
fi

# Cleanup Phase 1: Initial Setup
if [ -x "./cleanup_01_initial_setup.sh" ]; then
  ./cleanup_01_initial_setup.sh
fi

echo "===================================================================="
echo "SUCCESS: Agent Gateway & Apigee X Internal Cleanup Completed!"
echo "===================================================================="
