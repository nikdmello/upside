#!/usr/bin/env bash
set -euo pipefail

python3 -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8787 --reload
