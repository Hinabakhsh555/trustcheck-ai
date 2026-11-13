"""Deterministic private API checks (no paid Azure calls)."""
import json
import os
import unittest
from unittest.mock import patch

import httpx
from fastapi.testclient import TestClient
from backend.app import app


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, {
            "TRUSTCHECK_TEST_TOKEN": "test-token-private",
            "AZURE_OPENAI_ENDPOINT": "https://example.services.ai.azure.com",
            "AZURE_OPENAI_DEPLOYMENT": "piku-chat",
            "AZURE_OPENAI_API_KEY": "not-a-real-secret",
        }, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.client = TestClient(app)
        self.headers = {"Authorization": "Bearer test-token-private"}
        self.message = {"message": "Verify your account urgently by visiting a link.", "sender": "Unknown"}

    def _mock_azure(self, status=200, model_content=None, body=None):
        if model_content is None:
            model_content = {"risk": 82, "category": "Phishing", "explanation": "Urgent verification request.",
                             "indicators": ["Urgency", "Unverified sender"],
                             "action": "Use the official service website instead."}
        response = body or {"status": "completed", "output": [{"type": "message", "content": [
            {"type": "output_text", "text": json.dumps(model_content)}]}]}
        captured = {}
        def handler(req):
            captured["url"] = str(req.url)
            captured["json"] = json.loads(req.content)
            captured["api_key"] = req.headers.get("api-key")
            return httpx.Response(status, json=response)
        transport = httpx.MockTransport(handler)
        original = httpx.AsyncClient
        factory = lambda *args, **kwargs: original(*args, transport=transport, **kwargs)
        return patch("backend.app.httpx.AsyncClient", side_effect=factory), captured

    def test_health_does_not_claim_live_connection(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok", "ai_configuration_present": True})
        self.assertEqual(response.headers["Cache-Control"], "no-store")

    def test_missing_auth_is_rejected(self):
        self.assertEqual(self.client.post("/v1/analyze", json=self.message).status_code, 401)

    def test_wrong_auth_is_rejected(self):
        response = self.client.post("/v1/analyze", json=self.message, headers={"Authorization": "Bearer wrong"})
        self.assertEqual(response.status_code, 401)

    def test_missing_ai_config_fails_closed(self):
        os.environ.pop("AZURE_OPENAI_API_KEY")
        self.assertEqual(self.client.post("/v1/analyze", json=self.message, headers=self.headers).status_code, 503)

    def test_invalid_endpoint_fails_closed(self):
        os.environ["AZURE_OPENAI_ENDPOINT"] = "http://insecure.example"
        self.assertEqual(self.client.post("/v1/analyze", json=self.message, headers=self.headers).status_code, 503)

    def test_message_validation(self):
        for message in ("", "x" * 8001):
            response = self.client.post("/v1/analyze", json={"message": message}, headers=self.headers)
            self.assertEqual(response.status_code, 422)

    def test_successful_response_mapping_and_no_storage(self):
        mocked, captured = self._mock_azure()
        with mocked:
            response = self.client.post("/v1/analyze", json=self.message, headers=self.headers)
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["risk"], 82)
        self.assertFalse(response.json()["sender_verified"])
        self.assertEqual(captured["api_key"], "not-a-real-secret")
        self.assertEqual(captured["url"], "https://example.services.ai.azure.com/openai/v1/responses")
        self.assertIn("\nMessage", captured["json"]["input"])
        self.assertEqual(captured["json"]["text"]["format"]["type"], "json_schema")
        self.assertIs(captured["json"]["store"], False)
        self.assertEqual(response.headers["Cache-Control"], "no-store")

    def test_incomplete_output_is_rejected(self):
        mocked, _ = self._mock_azure(body={"status": "incomplete", "output": []})
        with mocked:
            response = self.client.post("/v1/analyze", json=self.message, headers=self.headers)
        self.assertEqual(response.status_code, 502)

    def test_invalid_risk_rejected(self):
        bad={"risk": True, "category": "Safe", "explanation": "text", "indicators": [], "action": "Do nothing"}
        mocked, _ = self._mock_azure(model_content=bad)
        with mocked:
            response = self.client.post("/v1/analyze", json=self.message, headers=self.headers)
        self.assertEqual(response.status_code, 502)

    def test_provider_error_is_sanitized(self):
        mocked, _ = self._mock_azure(status=429)
        with mocked:
            response = self.client.post("/v1/analyze", json=self.message, headers=self.headers)
        self.assertEqual(response.status_code, 502)
        self.assertEqual(response.json()["detail"], "AI analysis unavailable")


if __name__ == "__main__":
    unittest.main()
