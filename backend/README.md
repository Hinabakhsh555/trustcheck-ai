# TrustCheck AI — private backend prototype

FastAPI adapter for an existing Azure OpenAI deployment. This is **not production ready**.

## Run locally
Install Python 3.11+, `pip install -r backend/requirements.txt`, configure environment variables from `backend/.env.example` using a secure secrets store, then run `uvicorn backend.app:app --host 127.0.0.1 --port 8000`.

## Private test
POST `/v1/analyze` with JSON `{"message":"Example text","sender":"optional sender"}` and `Authorization: Bearer <TRUSTCHECK_TEST_TOKEN>`.

## Release blockers
- Confirm Azure deployment model, API version, endpoint compatibility, and model support for JSON mode.
- Implement user authentication, per-user quotas, abuse protection, and rate limiting; the shared test token is **not** adequate for a public Android app.
- Enforce a global Azure AI spending cap through application-side quotas and monitoring.
- Add privacy notice, opt-in transmission, data minimization and retention policy.
- Add automated tests, integration tests, multilingual evaluation, and adversarial prompt-injection tests.
- Integrate with Flutter only after secure authentication is available.
- Validate Play policy, signing and release build.

Do not commit API keys or put them inside an APK.
