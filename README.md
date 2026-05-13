# Canton DevRel Tool

**One command. Full Canton Network on your laptop.**

Built by Canton Foundation Developer Relations for hackathons, bootcamps, and anyone who needs a local Canton Network without waiting for DevNet whitelisting.

That's it. Three validators, a synchronizer, wallet UIs, Canton Coin, Scan UI, the whole official Splice LocalNet stack.

## Install

**macOS / Linux** (WSL 2 on Windows):

```bash
curl -fsSL https://raw.githubusercontent.com/Jatinp26/canton-devrel-tool/main/install.sh | bash
```

Then reload your shell:
```bash
source ~/.zshrc   # zsh
source ~/.bashrc  # bash
```

**Requirements:**
- Docker Desktop with **≥ 8 GB** memory allocated (Settings → Resources → Memory)
- `curl`, `jq`, `git` — available via `brew` (macOS) or `apt` (Linux)
- macOS or Linux only. Windows: use WSL 2.

The installer handles PATH setup and `/etc/hosts` entries for `*.localhost` domains.

## Commands

```bash
canton devrel start                        # download bundle + boot LocalNet

canton devrel stop                         # stop containers (data preserved)

canton devrel status                       # health check + port reference

canton devrel deploy ./my-app-0.0.1.dar    # upload your DAR to both participants

canton devrel logs                         # tail all logs

canton devrel logs <service>               # tail one service

canton devrel reset                        # wipe everything, start clean
```

## What Starts

| Service | URL | Credential |
|---------|-----|-------|
| App User Wallet UI | http://wallet.localhost:2000 | app-user |
| App Provider Wallet UI | http://wallet.localhost:3000 | app-provider |
| Scan UI | http://scan.localhost:4000 | - |
| SV UI | http://sv.localhost:4000 | sv |
| App Provider JSON API | http://localhost:3975 | - |
| App User JSON API | http://localhost:2975 | - |
| SV JSON API | http://localhost:4975 | - |
| App Provider Ledger API (gRPC) | localhost:3901 | - |
| App User Ledger API (gRPC) | localhost:2901 | - |
| SV Ledger API (gRPC) | localhost:4901 | - |
| PostgreSQL | localhost:5432 | - |

## First Run

On `canton devrel start`, the tool:

1. Downloads the official Splice LocalNet bundle from the Splice GitHub release (One-time only cached at `~/.canton-devrel/bundle/`)
2. Pulls the Canton/Splice Docker images (~5 min, also cached)
3. Boots the full network using the official LocalNet compose configuration

Subsequent runs skip steps 1 and 2 entirely and boot in ~30 seconds.

## Deploying Your DAR

Build your Daml project with `dpm build`, then:

```bash
canton devrel deploy ./your-project/.daml/dist/your-project-0.0.1.dar
```

Uploads your DAR to both the App Provider and App User participants, retrieves your package ID, and prints the template ID format for API calls.

## Interacting With Your Contracts

Once deployed, use the JSON Ledger API to create contracts, exercise choices, and query state.

## What It Is / Isn't

**Is:** A CLI that has the official [Splice LocalNet](https://docs.sync.global/app_dev/testing/localnet.html), the same Docker Compose configuration that Digital Asset ships with every Splice release, invoked with the exact commands from the official docs. No custom compose files, no approximations.

**Isn't:** A replacement for [cn-quickstart](https://github.com/digital-asset/cn-quickstart). Quickstart is a full developer project template with a reference app, Java backend, and React frontend. This tool is just the network layer to bring your own Daml project.

## Troubleshooting

**First run is slow**
Normal, the Splice bundle and Docker images download on first run. Everything is cached after that.

**Containers crash on startup**
Docker memory. Go to Docker Desktop Settings, Under Resources goto Memory and set to 8 GB minimum.

**`*.localhost` domains don't resolve**

```bash
echo "127.0.0.1  wallet.localhost scan.localhost sv.localhost" | sudo tee -a /etc/hosts
```

**Weird state / things not working**

```bash
canton devrel reset
canton devrel start
```

**See what's failing**

```bash
canton devrel logs
canton devrel logs canton     
canton devrel logs splice     
```

**Re-download the bundle** (if corrupted or upgrading)

```bash
rm -rf ~/.canton-devrel/bundle
canton devrel start
```

## Upgrading LocalNet version

Edit `~/.canton-devrel/.env` and change `IMAGE_TAG`:

```bash
IMAGE_TAG=0.5.11 
```

Then reset and restart:
```bash
canton devrel reset
rm -rf ~/.canton-devrel/bundle  
canton devrel start
```

# Part of the Canton Developer Hub

This is the fast start layer of the BuidL Experience on Canton.

| Want more? | Where to go |
|---|---|
| Understand LocalNet deeply, use PQS, integrate wallets | [LocalNet Deployment Guide](https://github.com/Jatinp26/Canton-Developer-Hub/blob/main/LocalNet%20Deployment%20Guide.md) |
| Build a full Canton app with backend, auth, frontend | [cn-quickstart](https://github.com/digital-asset/cn-quickstart) |
| Browse all Canton tools, SDKs, and APIs | [Canton Dev Toolings Guide](https://github.com/Jatinp26/Canton-Developer-Hub/blob/main/Canton%20Dev%20Toolings%20Guide.md) |

> *Built by [Jatin Pandya](https://x.com/Jpandya26), Developer Relations Manager, Canton Foundation.*