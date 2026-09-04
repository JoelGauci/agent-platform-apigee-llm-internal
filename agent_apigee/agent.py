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

import os
import logging
from dotenv import load_dotenv

import warnings
warnings.filterwarnings("ignore")
logging.basicConfig(level=logging.INFO)

from google.adk import Runner
from google.adk.agents import Agent
from google.adk.models.apigee_llm import ApigeeLlm
from google.adk.sessions import InMemorySessionService
from google.genai import types

# Step 1: Load environment variables
load_dotenv()
os.environ["GOOGLE_CLOUD_PROJECT"] = os.getenv("GOOGLE_CLOUD_PROJECT", "agent-platform-exp")
os.environ["GOOGLE_CLOUD_LOCATION"] = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
if not os.environ.get("GEMINI_API_KEY"):
    os.environ["GEMINI_API_KEY"] = "apigee-dummy-key"

class ApigeeAgentApp:
    """Reasoning Engine interface wrapper for Google ADK ApigeeLlm Agent"""

    def __init__(
        self,
        apigee_hostname: str | None = None,
        apigee_llm: str | None = None,
        apikey: str | None = None,
        model_name: str | None = None
    ):
        self.apigee_hostname = apigee_hostname or os.getenv("APIGEE_HOSTNAME")
        self.apigee_llm = apigee_llm or os.getenv("APIGEE_LLM", "/v1/llm-ai-gateway")
        self.apikey = apikey or os.getenv("APIKEY") or os.getenv("APIGEE_APIKEY")
        self.model_name = model_name or os.getenv("MODEL_NAME", "apigee/vertex_ai/gemini-2.5-flash")
        self._runner = None
        self._session_service = None

    def set_up(self):
        """Initialize ADK agent instance and runner on Reasoning Engine container startup"""
        if not self.apigee_hostname:
            raise ValueError("APIGEE_HOSTNAME is required but was not provided or set in environment.")
        if not self.apikey:
            raise ValueError("APIKEY is required but was not provided or set in environment.")

        os.environ["GOOGLE_CLOUD_PROJECT"] = os.getenv("GOOGLE_CLOUD_PROJECT", "agent-platform-exp")
        os.environ["GOOGLE_CLOUD_LOCATION"] = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
        if not os.environ.get("GEMINI_API_KEY"):
            os.environ["GEMINI_API_KEY"] = "apigee-dummy-key"

        custom_headers = {
            "x-apikey": self.apikey
        }
        model = ApigeeLlm(
            model=self.model_name,
            proxy_url=f"https://{self.apigee_hostname}{self.apigee_llm}",
            custom_headers=custom_headers
        )
        agent = Agent(
            name="simple_apigee_agent",
            model=model,
            instruction="You are a helpful and concise AI assistant powered by Apigee LLM Gateway."
        )
        self._session_service = InMemorySessionService()
        self._runner = Runner(
            agent=agent,
            app_name="simple_apigee_agent",
            session_service=self._session_service
        )

    async def query(self, prompt: str) -> str:
        """Async query entry point method required by Vertex AI ReasoningEngine"""
        if not self._runner:
            self.set_up()

        session = await self._session_service.create_session(
            app_name="simple_apigee_agent",
            user_id="user"
        )
        content = types.Content(
            role="user",
            parts=[types.Part(text=prompt)]
        )
        response_text = ""
        async for event in self._runner.run_async(
            session_id=session.id,
            user_id="user",
            new_message=content
        ):
            if hasattr(event, "content") and event.content and hasattr(event.content, "parts"):
                for part in event.content.parts:
                    if hasattr(part, "text") and part.text:
                        response_text += part.text
        return response_text

root_agent = ApigeeAgentApp()
