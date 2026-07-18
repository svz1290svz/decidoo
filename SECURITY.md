# Security Policy

## Reporting a vulnerability

Do not open a public issue for security vulnerabilities, exposed secrets, account takeover risks, payment issues or personal-data leaks.

Use GitHub private vulnerability reporting when it is enabled for this repository. Until then, contact the repository owner privately through the verified business channel.

Include:

- affected version and platform
- reproduction steps
- impact assessment
- proof of concept with personal data removed
- suggested mitigation, if known

## Supported versions

Only the latest release and the current `main` branch receive security fixes during the pre-launch stage.

## Secrets

Never commit API keys, signing certificates, service-account JSON files, Apple provisioning profiles, Android keystores or production environment files. Use GitHub Actions secrets and platform-specific secret stores.
