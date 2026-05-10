# Canton Devrel Tool

Direct CLI for Deploying on Canton LocalNet in an Simple Setup.

Built by [Jatin](https://x.com/Jpandya26), Developer Relations Manager, Canton Foundation. For anyone who needs a local Canton Network without the 10-day DevNet whitelisting wait. Three validators, a synchronizer, wallet UIs, Canton Coin, Keycloak, PQS — the whole stack.

## Install

**macOS / Linux** (WSL 2 for Windows users):

```bash
curl -fsSL https://raw.githubusercontent.com/Jatinp26/canton-devrel-tool/main/install.sh | bash
```

Then reload your shell:

```bash
source ~/.zshrc   # For Mac Legends
```
OR
```bash
source ~/.bashrc  # For others
```

**Requirements:**
- Docker Desktop with **≥ 8 GB** memory allocated (Settings > Resources > Memory)
- `curl`, `jq`, `git`...all available via `brew` (macOS) or `apt` (Linux)
- macOS or Linux only. Windows: use WSL 2.

## Relevent Commands

```bash
canton devrel start                        # boot LocalNet
canton devrel stop                         # stop (data preserved)
canton devrel status                       # health check + port reference
canton devrel deploy ./my-app-0.0.1.dar    # upload your DAR to LocalNet via Giving It's Path.
canton devrel logs                         # tail all logs
canton devrel reset                        # wipe everything, start clean
```

## What Starts

| Service | URL | Credentials |
|---------|-----|-------------|
| App User Wallet | http://wallet.localhost:2000 | app-user / abc123 |
| App Provider Wallet | http://wallet.localhost:3000 | app-provider / abc123 |
| Scan UI | http://scan.localhost:4000 | — |
| Keycloak | http://keycloak.localhost:8082 | admin / admin |
| App Provider JSON API | http://localhost:3975 | (use token) |
| App User JSON API | http://localhost:2975 | (use token) |
| App Provider Ledger API (gRPC) | localhost:3901 | — |
| App User Ledger API (gRPC) | localhost:2901 | — |

## Deploying Your DAR

Build your Daml project first with `dpm build`, then:

```bash
canton devrel deploy ./your-project/.daml/dist/your-project-0.0.1.dar
```

This uploads your DAR to both the App Provider and App User participants automatically, retrieves your package ID, and tells you the template ID format for API calls.

## What It Is / Isn't

**Is:** A stripped down Canton LocalNet pure network infrastructure. Three validators, a synchronizer, wallets, Keycloak, PQS. No reference app.

**Isn't:** A replacement for [cn-quickstart](https://github.com/digital-asset/cn-quickstart). This tool wraps the same Splice LocalNet images but removes the build step, the Makefile, and all the reference app scaffolding so you can focus on your own project on LocalNet.

**Not for production.** This is a local development environment. Admin ports and credentials are intentionally exposed for developer convenience only intending for Hackathons, bootcamps, etc.

## Troubleshooting

- **Containers crash on startup**

Docker memory. Go to Docker Desktop > Settings > Resources > Memory > set to 8 GB minimum.

- **`*.localhost` domains don't resolve**

```bash
echo "127.0.0.1  wallet.localhost scan.localhost keycloak.localhost" | sudo tee -a /etc/hosts
```

- **Weird state, things not working**

```bash
canton devrel reset
canton devrel start
```

- **See what's failing**

```bash
canton devrel logs canton
canton devrel logs splice
canton devrel logs keycloak
```

- **DAR upload fails with 401**

Keycloak token expired. Just re run `canton devrel deploy` it fetches a fresh token each time.

## Updating

Re-run the installer to get the latest version:

```bash
curl -fsSL https://raw.githubusercontent.com/Jatinp26/canton-devrel-tool/main/install.sh | bash
```

> For the cn_quickstart LocalNet Setup Guide, tooling catalogue, and more, Check [Canton Developer Hub](https://github.com/Jatinp26/Canton-Developer-Hub)
>
> Questions? Join [Canton Forum](https://forum.canton.network/)
