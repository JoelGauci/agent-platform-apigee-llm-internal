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

# Exit immediately if a command exits with a non-zero status
set -e

# Step 1: Load shared environment variables if available
if [ -f "./env.sh" ]; then
  source ./env.sh
fi

echo "===================================================================="
echo "Phase 1: Initial Environment Setup & API Enablement (01_initial_setup.sh)"
echo "===================================================================="

# Step 2: Set the default active Google Cloud project
gcloud config set project agent-platform-exp

# Step 3: Check user authentication session and run gcloud auth login only if needed
if ! gcloud auth print-access-token &>/dev/null; then
  echo "INFO: User session not authenticated. Triggering interactive gcloud auth login..."
  gcloud auth login
else
  echo "INFO: User session is already authenticated."
fi

# Step 4: Check Application Default Credentials (ADC) and run login only if needed
if ! gcloud auth application-default print-access-token &>/dev/null; then
  echo "INFO: Application Default Credentials not found. Triggering gcloud auth application-default login..."
  gcloud auth application-default login
else
  echo "INFO: Application Default Credentials are already configured."
fi

# Step 5: Export core shell variables for location and naming convention
export SLUG="apigee"
export REGION="us-central1"
echo "SLUG=${SLUG}"
echo "REGION=${REGION}"

# Step 6: Automatically query and set GCP project and identity variables
export PROJ_ID=$(gcloud config list --format="value(core.project)")
export PROJ_NO=$(gcloud projects describe ${PROJ_ID} --format="value(projectNumber)")
export ORG_ID=$(gcloud projects get-ancestors ${PROJ_ID} --format="value(id)" 2>/dev/null | tail -n 1 || echo "")
export USER_IDENTITY=$(gcloud config get-value account 2>/dev/null || echo "")
echo "PROJ_ID=${PROJ_ID}"
echo "PROJ_NO=${PROJ_NO}"
echo "ORG_ID=${ORG_ID}"
echo "USER_IDENTITY=${USER_IDENTITY}"

# Step 7: Automatically construct resource names and URIs
export AGW_NAME="agw-${SLUG}-${REGION}-ata"
export AGW_URI="projects/${PROJ_ID}/locations/${REGION}/agentGateways/${AGW_NAME}"
export RE_AGENT_NAME="simple-agent"
export RE_AGENT_ID_SET="principalSet://agents.global.org-${ORG_ID}.system.id.goog/attribute.platformContainer/aiplatform/projects/${PROJ_NO}"
export STAGING_BUCKET="agent-staging-${PROJ_NO}"
export APIGEE_SVC_ATTACHMENT="projects/x45914945fdb2794d-tp/regions/us-central1/serviceAttachments/apigee-us-central1-5ype"

# Step 8: Ensure local directory exists for generated YAML configuration artifacts
mkdir -p cfg

# Step 9: Enable all required Google Cloud APIs for Agent Gateway, Compute, DNS, and Certificate Manager
echo "INFO: Enabling required Google Cloud service APIs..."
gcloud services enable \
  agentregistry.googleapis.com \
  aiplatform.googleapis.com \
  apphub.googleapis.com \
  apptopology.googleapis.com \
  cloudapiregistry.googleapis.com \
  cloudtrace.googleapis.com \
  compute.googleapis.com \
  dataform.googleapis.com \
  iam.googleapis.com \
  iamconnectors.googleapis.com \
  iap.googleapis.com \
  logging.googleapis.com \
  modelarmor.googleapis.com \
  monitoring.googleapis.com \
  networksecurity.googleapis.com \
  networkservices.googleapis.com \
  notebooks.googleapis.com \
  observability.googleapis.com \
  securitycenter.googleapis.com \
  saasservicemgmt.googleapis.com \
  storage.googleapis.com \
  telemetry.googleapis.com \
  texttospeech.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  dns.googleapis.com \
  certificatemanager.googleapis.com

echo "INFO: Phase 1 Initial Setup completed successfully."
