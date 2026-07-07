# Pratham — OPD Pre-Consultation System

An AI-assisted outpatient (OPD) pre-consultation system for Indian hospitals. While a patient
waits, they complete a short intake on their own phone (by scanning a poster QR); the system
collects their history, photographs of old prescriptions/reports, and vitals, then hands the
doctor a **ready, structured summary** before the patient walks in. It also supports triage
prioritisation, digital prescriptions with a tamper-proof QR, and an admin console.

> **Clinical-use note:** the AI outputs (summary, triage, document reading) are **decision
> support only** — a doctor reviews and decides. They are not a diagnosis and are not a
> substitute for clinical judgement.

---

## Table of contents
1. [What it does](#what-it-does)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick start (local)](#quick-start-local)
5. [Security & secrets — plain-English setup](#security--secrets--plain-english-setup)
6. [First-time hospital setup](#first-time-hospital-setup)
7. [The links (URLs)](#the-links-urls)
8. [Production deployment](#production-deployment)
9. [Optional integrations](#optional-integrations)
10. [Project structure](#project-structure)
11. [Operations & staff training](#operations--staff-training)

---

## What it does
- **Patient self-intake** — scan a single hospital QR → choose language (English / हिंदी / తెలుగు) →
  phone + OTP → details → department (+ optional preferred doctor) → consent → photograph old
  documents → symptom questions → review & submit → queue token. Voice input and read-aloud are
  built in. (Vitals are recorded separately by a nurse/staff member, not entered by the patient.)
- **AI pre-consultation summary** — merges answers, extracted document data (OCR), and vitals into a
  structured summary with an FHIR export for the doctor.
- **Triage** — RED / AMBER / GREEN, urgent patients sorted to the front of the queue; a RED case
  raises a real-time nursing-station alert. Triage only ever *escalates* automatically — it never
  silently lowers a flag a safety question raised.
- **Doctor dashboard** — department queue, patient summary with previous-visit history, drug-
  interaction checks, an optional ambient scribe, and a digital prescription with a **signed QR**
  that a pharmacy can verify.
- **Admin console (HIS)** — manage departments and doctors, view patients, operational analytics,
  and edit the questionnaire / drug formulary. Every admin change is attributed to a named person.
- **Privacy & security built in** — JWT-authenticated services, role-gating, encryption of uploaded
  files at rest (in production), phone numbers masked in logs, and an access audit trail of who
  viewed which patient.

## Architecture
Six containers behind one gateway (started together with Docker Compose):

| Service | Role |
|---|---|
| `gateway` (Nginx) | Single entry point; routes to the right service; rate-limiting & security headers |
| `frontend` (Next.js) | Patient flow, doctor dashboard, admin console |
| `node-backend` (Express) | Sessions, auth, questionnaire, queue/tokens, prescriptions, analytics |
| `python-backend` (FastAPI) | AI: report generation, triage, OCR, drug checks, scribe |
| `postgres` | Database (schema auto-migrates on startup) |
| `redis` | Real-time nursing alerts (pub/sub) |
| `minio` | Object storage for uploaded documents & audio |

## Prerequisites
- **Docker Desktop** (includes Docker Compose) — this is all you need to run the whole system.
- **Node.js** — only if you want to run the helper scripts (secret generator, QR poster).
- A machine with ~4 GB free RAM for the containers.

## Quick start (local)
```bash
# 1. Copy the environment template
cp .env.example .env

# 2. Generate strong secrets and paste them into .env (see the next section)
node scripts/gen-secrets.js

# 3. Start everything (first run pulls images — a few minutes)
docker compose up --build
```
When it finishes, open **http://localhost/?h=hospital_01** for the patient flow. The system ships
with a single **General OPD** department and **no doctors** — create your real doctors in the admin
console first (see [First-time hospital setup](#first-time-hospital-setup)).

> Code changes need a **rebuild**, not just a restart:
> `docker compose build <service> && docker compose up -d <service> && docker compose restart gateway`

---

## Security & secrets — plain-English setup
The system uses several secret values. **You do not need a security background** — run one command,
paste the output into a file, and you're done. **Never share these values or commit the `.env` file.**

**Generate them all at once:**
```bash
node scripts/gen-secrets.js      # prints ready-to-paste lines; copy them into your .env
```

What each secret is, in plain terms:

| Secret in `.env` | What it protects (plain English) |
|---|---|
| `JWT_SECRET` | The key used to sign **login tokens**. It's how the system trusts that a logged-in doctor/admin/patient is really them. If this leaks, someone could impersonate users. Long, random, secret. |
| `ADMIN_PASSCODE` | The **password to enter the admin console** (HIS). Give it only to admin staff. |
| `QR_SIGNING_SECRET` | Signs the **prescription QR codes** so a slip can't be forged or edited. A pharmacy scan fails if the slip was tampered with. |
| `OTP_SECRET` | Protects the one-time SMS codes patients use to verify their phone. |
| `POSTGRES_PASSWORD` | The **database** password. |
| `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` | The **file-storage** username/password (uploaded documents & audio). |
| `MINIO_KMS_SECRET_KEY` | The key that **encrypts uploaded files on disk** (in production). ⚠️ **Back this one up somewhere safe — if you lose it, encrypted files can't be opened, ever. Never change it after go-live.** |

Two things the system does to keep you safe:
- **In production it refuses to start** with weak or default secrets (e.g. a leftover placeholder
  `JWT_SECRET` or `QR_SIGNING_SECRET`) — so you can't accidentally deploy insecurely.
- **Patient phone numbers are masked in logs**, and there's an **audit trail** of who viewed each
  patient's record.

The other keys in `.env.example` (`GEMINI_API_KEY`, `TWILIO_*`, `BHASHINI_*`, etc.) are **optional
integrations** — the app runs without them (see [Optional integrations](#optional-integrations)).

---

## First-time hospital setup
Do this once, before letting real patients in:

1. **Log into the admin console** → **http://localhost/his** → enter your `ADMIN_PASSCODE` and **your
   name** (your name is recorded on every change you make — this is deliberate, for accountability).
   > **What's the passcode?** There is no factory default — your admin passcode is simply the
   > `ADMIN_PASSCODE` value you put in `.env` (set a strong one with `node scripts/gen-secrets.js`;
   > it must be at least 6 characters). To change it later, edit `.env` and restart the backend.
2. **Create your departments** (HIS → Departments) — e.g. Cardiology, General Medicine, whatever your
   OPD runs. Set each one's icon and whether it collects vitals. (A generic *General OPD* is
   pre-created as a starting point; edit or deactivate it as you like.)
3. **Create your doctors** (HIS → Doctors) — you set each doctor's **login PIN** here when you create
   them. That PIN (together with the doctor's phone number) is what they type at the doctor dashboard
   — there is no default PIN. Tell each doctor to change their PIN on first login.
4. **Set your hospital identity** — put your real `HOSPITAL_ID` and `HOSPITAL_NAME` in `.env`.
5. **Print the QR poster** — run `node scripts/generate-qr.js https://your-domain` (or open
   `scripts/qr-poster.html`) and place it where patients check in.
6. **Do one test patient** end-to-end before going live.

## The links (URLs)
Locally these are all under `http://localhost` (in production, your HTTPS domain):

| Screen | URL | Who |
|---|---|---|
| Patient intake | `http://localhost/?h=<HOSPITAL_ID>` (e.g. `?h=hospital_01`) | Patients (via poster QR) |
| Public "Now Serving" board | `http://localhost/queue?dept=<CODE>` (e.g. `?dept=OPD`) | Waiting-room screen |
| Doctor dashboard | `http://localhost/doctor` | Doctors (phone + PIN) |
| Admin console (HIS) | `http://localhost/his` | Admin (passcode + name) |
| Prescription verify | `http://localhost/rx/verify?d=…` | Pharmacy (by scanning the slip QR) |
| File storage console | `http://localhost:9001` | IT only (MinIO login) |

**Where each login comes from** (none of these are hardcoded defaults — they all come from *your* setup):
- **Admin console** — the `ADMIN_PASSCODE` you set in `.env`, plus your name (for the audit trail).
- **Doctor dashboard** — the doctor's phone number + the PIN you set for that doctor in the admin console.
- **Patient intake** — `<HOSPITAL_ID>` is the `HOSPITAL_ID` value from your `.env`.
- **File storage console** — the `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` from your `.env` (IT only).

## Production deployment
A production topology with automatic HTTPS is included.
```bash
# One-time: fill .env with strong secrets (node scripts/gen-secrets.js) and point
# your domain's DNS at the server. Then:
DOMAIN=opd.yourhospital.in docker compose -f docker-compose.prod.yml up -d --build
```
This runs the app behind **Caddy**, which obtains and renews a free HTTPS certificate automatically.
Only ports 80/443 are exposed; the database, file storage, and backends stay on the internal network.
Full deploy / update / backup / restore / monitoring steps are in **[`deploy/OPERATIONS.md`](deploy/OPERATIONS.md)**.

## Optional integrations

> **Bring your own API keys.** This repository ships with **no** third-party API keys — for
> security, keys must never be committed. To enable the AI, SMS, or Indian-language voice features,
> **you supply your own keys** for whichever providers you choose and put them in your `.env` file
> (see `.env.example` for the exact variable names). Each provider is signed up for on that
> provider's own website. Without any keys the app still runs and simply falls back to its built-in
> rule-based behaviour.

All of the below are optional — the app degrades gracefully without them:
- **AI models** — get an API key from **one** provider and set it in `.env`: `GEMINI_API_KEY`
  (Google, recommended — has a free tier), or `OPENAI_API_KEY`, `GROQ_API_KEY`, or
  `ANTHROPIC_API_KEY` as alternatives/fallbacks. These power the document OCR and the AI summaries.
  With none set, the system uses rule-based logic + Tesseract OCR. For data that must stay
  on-premises, point `LOCAL_VISION_BASE_URL` at a locally hosted vision model instead.
- **SMS OTP** — set `TWILIO_*` (or another provider's) credentials to send real OTP texts. Without
  them, in development the code is shown on-screen; production requires SMS to be configured.
  **Note:** sending SMS to Indian numbers requires **DLT registration** (a regulatory step)
  regardless of provider.
- **Indian-language voice** (`BHASHINI_*`) — enables high-quality Hindi/Telugu speech-to-text.

**Other configuration**
- `APP_TIMEZONE` (default `Asia/Kolkata`) — the timezone that defines a "service day". The daily
  per-department queue-token counter resets at local midnight in this zone, so tokens roll over at
  12 am hospital time regardless of the server's own timezone. Change it only if you deploy outside
  IST.

## Project structure
```
db/migrations/        # SQL schema, applied automatically on startup (in order)
deploy/               # Production compose helpers, Caddy config, OPERATIONS runbook
docs/                 # Architecture notes + printable staff training one-pagers
frontend/             # Next.js app (patient, doctor, admin)
scripts/              # Secret generator, QR poster, backup/restore, smoke test
services/
  gateway/            # Nginx reverse-proxy config
  node-backend/       # Express API (sessions, auth, queue, prescriptions, analytics)
  python-backend/     # FastAPI AI services (report, triage, OCR, scribe)
docker-compose.yml        # Local development
docker-compose.prod.yml   # Production (Caddy + HTTPS)
```
See **[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)** for how the pieces fit together, the database-
migration rules, and code conventions.

## Operations & staff training
- **Runbook** (deploy, backups, restore, monitoring, paper-fallback during downtime):
  [`deploy/OPERATIONS.md`](deploy/OPERATIONS.md)
- **Staff training one-pagers** (help-desk, doctors, admin), print-ready:
  [`docs/training/`](docs/training/)

---

*Built for the Pratham OPD pilot. Handle patient data as sensitive personal health information under
India's DPDP Act 2023 — see the operations runbook for the privacy controls in place and the
organisational steps still required.*
