# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import os
import sys
import cloudpickle
import google.auth
from google.auth.transport.requests import Request

import vertexai
from vertexai.preview import reasoning_engines
import vertexai.reasoning_engines._reasoning_engines as _re_internal
from google.cloud import aiplatform_v1beta1 as aiplatform

def main():
    # Step 1: Parse CLI deployment arguments
    parser = argparse.ArgumentParser(description="Deploy ADK Agent to Vertex AI Agent Runtime")
    parser.add_argument("--project", required=True, help="Google Cloud Project ID")
    parser.add_argument("--region", default="us-central1", help="GCP Region")
    parser.add_argument("--staging-bucket", required=True, help="GCS Staging Bucket Name")
    parser.add_argument("--display-name", default="simple-agent", help="Reasoning Engine Display Name")
    parser.add_argument("--agent-gateway-egress", required=True, help="Agent Gateway Resource URI")
    parser.add_argument("--apigee-hostname", default=os.getenv("APIGEE_HOSTNAME"), help="Apigee Hostname")
    parser.add_argument("--apigee-llm", default=os.getenv("APIGEE_LLM", "/v1/llm-ai-gateway"), help="Apigee LLM Path")
    parser.add_argument("--apikey", default=os.getenv("APIKEY") or os.getenv("APIGEE_APIKEY"), help="Apigee API Key")
    parser.add_argument("--model-name", default=os.getenv("MODEL_NAME", "apigee/vertex_ai/gemini-2.5-flash"), help="Model Name")
    args = parser.parse_args()

    # Step 2: Initialize Vertex AI SDK with project, region, and GCS staging bucket
    staging_uri = f"gs://{args.staging_bucket}"
    print(f"INFO: Initializing Vertex AI SDK for project {args.project} in {args.region}...")
    vertexai.init(
        project=args.project,
        location=args.region,
        staging_bucket=staging_uri
    )

    # Step 3: Add directory containing agent.py to sys.path and register module by value for cloudpickle
    agent_dir = os.path.dirname(os.path.abspath(__file__))
    if agent_dir not in sys.path:
        sys.path.insert(0, agent_dir)
    import agent

    # Instruct cloudpickle to serialize agent module definition by value directly into reasoning_engine.pkl
    cloudpickle.register_pickle_by_value(agent)
    root_agent = agent.ApigeeAgentApp(
        apigee_hostname=args.apigee_hostname,
        apigee_llm=args.apigee_llm,
        apikey=args.apikey,
        model_name=args.model_name
    )

    print(f"INFO: Packaging Agent '{args.display_name}' for Agent Runtime...")

    agent_file = os.path.join(agent_dir, "agent.py")

    # Step 4: Prepare package artifacts using Vertex AI SDK helper
    _re_internal._prepare(
        reasoning_engine=root_agent,
        requirements=[
            "google-adk>=1.18.0",
            "google-cloud-aiplatform>=1.70.0",
            "google-genai",
            "python-dotenv",
            "cloudpickle",
            "requests"
        ],
        project=args.project,
        location=args.region,
        staging_bucket=staging_uri,
        gcs_dir_name="reasoning_engine",
        extra_packages=[agent_file]
    )

    # Step 5: Build ReasoningEngineSpec with pscInterfaceConfig and identityType directly
    package_spec = aiplatform.ReasoningEngineSpec.PackageSpec(
        python_version=f"{sys.version_info.major}.{sys.version_info.minor}",
        pickle_object_gcs_uri=f"{staging_uri}/reasoning_engine/reasoning_engine.pkl",
        dependency_files_gcs_uri=f"{staging_uri}/reasoning_engine/dependencies.tar.gz",
        requirements_gcs_uri=f"{staging_uri}/reasoning_engine/requirements.txt"
    )

    psc_config = aiplatform.PscInterfaceConfig(
        network_attachment=f"projects/{args.project}/regions/{args.region}/networkAttachments/psc-na-{args.region}-agw",
        dns_peering_configs=[
            aiplatform.DnsPeeringConfig(
                domain="iloveagents.io.",
                target_project=args.project,
                target_network="vnet-apigee"
            )
        ]
    )

    deployment_spec = aiplatform.ReasoningEngineSpec.DeploymentSpec(
        psc_interface_config=psc_config
    )

    class_methods = _re_internal._generate_class_methods_spec_or_raise(
        root_agent,
        _re_internal._get_registered_operations(root_agent)
    )

    reasoning_engine_spec = aiplatform.ReasoningEngineSpec(
        package_spec=package_spec,
        deployment_spec=deployment_spec,
        identity_type=aiplatform.ReasoningEngineSpec.IdentityType.AGENT_IDENTITY
    )
    reasoning_engine_spec.class_methods.extend(class_methods)

    reasoning_engine_resource = aiplatform.ReasoningEngine(
        display_name=args.display_name,
        description="Simple ADK Agent using ApigeeLLM Gateway",
        spec=reasoning_engine_spec
    )

    # Step 6: Call ReasoningEngineServiceClient to create resource with pscInterfaceConfig baked in at creation
    print(f"INFO: Creating Reasoning Engine on Agent Runtime with pscInterfaceConfig and AGENT_IDENTITY...")
    client_options = {"api_endpoint": f"{args.region}-aiplatform.googleapis.com"}
    client = aiplatform.ReasoningEngineServiceClient(client_options=client_options)
    parent = f"projects/{args.project}/locations/{args.region}"

    operation = client.create_reasoning_engine(
        parent=parent,
        reasoning_engine=reasoning_engine_resource
    )

    print("INFO: Waiting for Reasoning Engine creation to complete...")
    result = operation.result()
    engine_id = result.name.split("/")[-1]
    print(f"INFO: Reasoning Engine created successfully (ID: {engine_id}): {result.name}")

    # Step 7: Save Reasoning Engine URI and ID to local environment file
    repo_root = os.path.dirname(agent_dir)
    cfg_dir = os.path.join(repo_root, "cfg")
    os.makedirs(cfg_dir, exist_ok=True)
    env_file = os.path.join(cfg_dir, "reasoning_engine.env")
    with open(env_file, "w") as f:
        f.write(f"export RE_ENGINE_ID=\"{engine_id}\"\n")
        f.write(f"export RE_ENGINE_URI=\"{result.name}\"\n")

    print(f"SUCCESS: Agent deployed and configured successfully on Agent Runtime!")
    print(f"INFO: Resource Name: {result.name}")

if __name__ == "__main__":
    main()
