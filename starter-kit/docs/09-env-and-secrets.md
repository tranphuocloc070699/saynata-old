# 09. Config, env and secrets

## Rules

1. **Config comes from env vars** (12-factor). The same build runs locally, in staging and in production.
2. **`.env.example` is the contract.** Every key is listed with a comment (where to get it, what values are allowed).
   `.env` is git-ignored. `scripts/doctor.sh` checks that your `.env` has every key from the example (it never prints values).
3. **Validate at start**: Spring `@ConfigurationProperties`/yml defaults, zod (`web/src/config/env.ts`),
   pydantic-settings (`python/src/app/config.py`), `AppConfig` (iOS). A missing key crashes at start, not at 3 am.
4. **Secrets are never in the frontend or the app binary.** `VITE_*` and Info.plist values are public.
   Paid API keys stay in the backend.
5. **Agents never see secrets.** The kit has deny rules for `Read(.env*)`, and a hook that blocks `cat .env`,
   `env`, and `printenv`. Agents work from `.env.example`.
6. **Scan before commit and in CI**: `gitleaks` in lefthook and in GitHub Actions.

## Where secrets live (pick the simplest that fits)

| Situation | Use |
|---|---|
| Solo, local dev | `.env` files + a password manager to keep a copy |
| CI | GitHub Actions secrets (and environments: `staging`, `production` with required review) |
| One VPS | `.env` on the server, `chmod 600`, owned by the app user; or `systemd` `EnvironmentFile` |
| Team, or you want the secrets in git | **SOPS + age** (encrypted files in the repo), or **1Password CLI** (`op run --env-file`) |
| Many services / cloud | The cloud's secret manager (AWS SSM/Secrets Manager, GCP Secret Manager), or Doppler/Infisical |

`dotenvx` (encrypted `.env`) is also fine. Never commit its private key.

## When a secret leaks

1. **Rotate it first** (make a new key, revoke the old one). Deleting the commit is not enough: it is
   already cached, forked, and scanned by bots within minutes.
2. Then clean the history if you want, and check the provider's logs for misuse.
3. Add the pattern to gitleaks if it was not caught.

## Real examples

- *The Twelve-Factor App*, III Config: <https://12factor.net/config>
- `gitleaks`, `getsops/sops` + `FiloSottile/age`, 1Password `op run`.
- This repo: `backend/.env.example` + doc-11 (Saynata keeps every key documented in one place).
