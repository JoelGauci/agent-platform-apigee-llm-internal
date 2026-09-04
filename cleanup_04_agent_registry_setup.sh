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
echo "Cleanup Phase 4: Agent Registry Cleanup (cleanup_04_agent_registry_setup.sh)"
echo "===================================================================="

# Delete Agent Registry services
gcloud agent-registry services delete apigeex --location=${REGION} --quiet || true
gcloud agent-registry services delete core-gapi-services --location=${REGION} --quiet || true

echo "INFO: Cleanup Phase 4 completed successfully."
