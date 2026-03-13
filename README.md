# CSC468-Cloud - Ryan Fioravanti
---
 
## Vision
 
The system is split into two containerized services that communicate over REST (HTTP/JSON):
 
```
┌─────────────────────────────────────────────────────────────────┐
│                         User's Browser                          │
└───────────────────────────────┬─────────────────────────────────┘
                                │  HTTPS
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Frontend Service                            │
│                   React + Vite (Node)                           │
│                                                                 │
│  • Login / register UI (JWT-based auth)                         │
│  • Sidebar dashboard — list repos & reviews                     │
│  • Dark terminal aesthetic                                      │
│  • Submits review requests, polls for results                   │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                │  REST API  (HTTP/JSON)
                                │  POST /reviews, GET /reviews/{id}
                                │  POST /auth/login, POST /auth/register
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Backend Service                            │
│                   FastAPI (Python 3.11)                         │
│                                                                 │
│  • JWT authentication (python-jose + passlib/bcrypt)           │
│  • GitHub API integration — fetch PR diffs & file trees        │
│  • Anthropic Claude API — generate structured code feedback    │
│  • PostgreSQL ORM (SQLAlchemy) — store users & reviews         │
└────────────┬──────────────────────────────────┬────────────────┘
             │                                  │
             │  SQL (TCP 5432)                  │  HTTPS
             ▼                                  ▼
┌─────────────────────┐             ┌───────────────────────┐
│  PostgreSQL          │             │  External APIs        │
│  Database            │             │  • GitHub REST API    │
│  (persistent vol.)   │             │  • Anthropic API      │
└─────────────────────┘             └───────────────────────┘
```
 
**Communication summary:**
 
| Link | Protocol | Details |
|---|---|---|
| Browser → Frontend | HTTPS | Served as static SPA |
| Frontend → Backend | REST over HTTP/JSON | Port 8000; CORS configured |
| Backend → PostgreSQL | TCP (port 5432) | SQLAlchemy connection pool |
| Backend → GitHub | HTTPS | GitHub REST API v3 |
| Backend → Anthropic | HTTPS | Claude API (`/v1/messages`) |
 
---
 
## Proposal
 
| Container | Base Image | Rationale |
|---|---|---|
| Backend | `python:3.11-slim` | Slim Debian base keeps the image small while supporting C extensions required by `bcrypt` and `cryptography`. Alpine would require manually installing `gcc` and `musl-dev` to compile them. |
| Frontend | `node:20-alpine` → `nginx:alpine` | Multi-stage build: Node compiles the Vite bundle, then only the static `dist/` files are copied into a minimal nginx image. No Node.js ships in the final ~25 MB image. |
| Database | `postgres:16-alpine` | Official Postgres image on Alpine. No custom Dockerfile needed — configured via environment variables in `docker-compose.yml` with a named volume for persistence. |
 
---
