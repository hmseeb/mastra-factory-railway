# mastra-factory-railway

Container image for the [Mastra Factory](https://mastra.ai/factory) Railway template.

It builds upstream [mastra-ai/softwarefactory-template](https://github.com/mastra-ai/softwarefactory-template) at a pinned commit (`UPSTREAM_REF` in `image/Dockerfile`) with two additions:

- `git`, `gh` and common build tools, so the local sandbox can clone, test and open pull requests.
- A sign-in allowlist: only verified WorkOS emails listed in `FACTORY_ALLOWED_EMAILS` get in, and the server refuses to boot without it.

`test/contract.sh` is the image contract, run in CI before every push to `ghcr.io/hmseeb/mastra-factory-railway`.
