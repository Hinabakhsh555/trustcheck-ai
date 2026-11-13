# TrustCheck AI V1.2 — Release Verification Record

Last assessed: 2026-11-14 (UTC+05). This is a **test candidate**, not a public AI release.

## Verified
- GitHub Android run [#43497790948](https://github.com/Hinabakhsh555/trustcheck-ai/actions/runs/43497790948) completed successfully. It generated a **debug** APK named trustcheck-ai-debug-apk; release signing and Play Store distribution were **not** tested.
- Backend Python syntax, mock-Azure API behavior, input validation, authentication rejection, error handling and JSON response mapping passed **10 deterministic tests** in GitHub Actions run [#43499683509](https://github.com/Hinabakhsh555/trustcheck-ai/actions/runs/43499683509). **No live inference occurred** in those tests.
- New Azure Functions workflow packages only the API files and requests a remote Python build for Flex Consumption.

## Blocked — live Azure deployment
- The earlier workflow run [#41227045776](https://github.com/Hinabakhsh555/trustcheck-ai/actions/runs/41227045776) failed at Azure login because Actions client ID and tenant ID values were missing.
- New deployment workflow checks for repository variables AZURE_CLIENT_ID, AZURE_TENANT_ID, and AZURE_SUBSCRIPTION_ID. Run #43499683509 **skipped** Azure deployment because these variables are not configured.
- The managed identity's federated credential subject and the GitHub OIDC subject must match. Repositories created after 2026-07-15 use immutable IDs by default.
- Backend Function App server-side settings (Azure endpoint, model deployment, API authentication and private test token) must be securely configured in Azure.
- There is **no verified live Azure AI analysis response through this backend**.

## Release blockers
1. Configure OIDC repository variables and confirm Azure authentication/deployment.
2. Verify a real Azure inference request with a synthetic harmless message. Do not log or publish secrets.
3. Implement production-grade per-user authorization, rate limits, quota/spending controls and abuse monitoring. The current shared private test token must **not** ship inside the APK.
4. Add explicit, informed user consent before sending message content to the cloud and define a privacy/retention policy.
5. Connect Flutter to the secured backend with network/loading/error states and offline fallback. The current V1.2 APK uses the **local heuristic risk engine**.
6. Validate detection quality across countries, languages, false positives, sender ID spoofing and lookalikes. The sender-ID check is not official sender authentication.
7. Configure private Play upload signing and build a properly signed release AAB. The CI debug keystore is public test material only.
8. Verify any Azure trial credit expiry and subscription spending status before live calls.

**Do not label this candidate a production AI release until the live backend test and mobile end-to-end tests pass.**
