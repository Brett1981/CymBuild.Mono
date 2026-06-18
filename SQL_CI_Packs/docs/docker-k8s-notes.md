# Docker / Kubernetes relationship

The supplied PWA/API Dockerfile and Kubernetes manifests are runtime deployment concerns.

The onboarding migration should not be baked into:
- PWA container startup
- API container startup
- Kubernetes deployment lifecycle hooks

Reason:
- The migration writes business/configuration data.
- It needs preview, validation and manual approval gates.
- It should be auditable as a deployment job.

If this is later moved into Kubernetes, prefer a dedicated one-shot Job that runs the same SQL scripts with environment-specific Secrets, not an initContainer on the API/PWA.
