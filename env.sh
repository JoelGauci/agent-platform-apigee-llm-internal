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

# Common environment variables for Agent Gateway & Apigee X internal integration
export SLUG="apigee"
export REGION="us-central1"

export PROJ_ID=$(gcloud config list --format="value(core.project)" 2>/dev/null || echo "agent-platform-exp")
export PROJ_NO=$(gcloud projects describe ${PROJ_ID} --format="value(projectNumber)" 2>/dev/null || echo "")
export ORG_ID=$(gcloud projects get-ancestors ${PROJ_ID} --format="value(id)" 2>/dev/null | tail -n 1 || echo "")
export USER_IDENTITY=$(gcloud config get-value account 2>/dev/null || echo "")

export AGW_NAME="agw-${SLUG}-${REGION}-ata"
export AGW_URI="projects/${PROJ_ID}/locations/${REGION}/agentGateways/${AGW_NAME}"
export RE_AGENT_NAME="simple-agent"
export RE_AGENT_ID_SET="principalSet://agents.global.org-${ORG_ID}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJ_NO}"
export STAGING_BUCKET="agent-staging-${PROJ_NO}"
export APIGEE_SVC_ATTACHMENT="projects/x45914945fdb2794d-tp/regions/us-central1/serviceAttachments/apigee-us-central1-5ype"

# Apigee LLM AI Gateway configuration and credentials
export APIGEE_HOSTNAME="${APIGEE_HOSTNAME:-apigee.iloveagents.io}"
export APIGEE_LLM="${APIGEE_LLM:-/v1/llm-ai-gateway}"
export APIGEE_APIKEY="${APIGEE_APIKEY:-${APIKEY:-VcCX3WPLWKmtxbiQ28IVWJAzp88d41g0G1xGoHPZfbvCYLCG}}"
export MODEL_NAME="${MODEL_NAME:-apigee/vertex_ai/gemini-2.5-flash}"
