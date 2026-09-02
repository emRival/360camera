#!/bin/bash
# Check latest build status from GitHub Actions
REPO="emRival/360camera"
RUN_ID=$(gh run list --limit 1 --repo $REPO --json databaseId --jq '.[0].databaseId')

echo "=== Latest Run: $RUN_ID ==="
gh run view $RUN_ID --repo $REPO --json status,conclusion --jq '"Status: \(.status) | Conclusion: \(.conclusion)"'

if [ "$(gh run view $RUN_ID --repo $REPO --json conclusion --jq '.conclusion')" = "failure" ]; then
  echo ""
  echo "=== FAILED STEPS ==="
  gh run view $RUN_ID --repo $REPO --log-failed 2>&1 | tail -30
fi
