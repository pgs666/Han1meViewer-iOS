#!/usr/bin/env bash
set -euo pipefail

PAGER_FILE="${1:-iosApp/VideoDetailPager.swift}"

if [ ! -f "$PAGER_FILE" ]; then
  echo "Missing pager file: $PAGER_FILE" >&2
  exit 1
fi

forbidden_patterns=(
  "VideoDetailHeaderAttachmentState"
  "headerAttachmentView"
  "canAttachHeaderToListHeader"
  "applyHeaderAttachment"
)

for pattern in "${forbidden_patterns[@]}"; do
  if grep -n "$pattern" "$PAGER_FILE"; then
    echo "Forbidden pager header attachment pattern found: $pattern" >&2
    exit 1
  fi
done

if ! grep -q "view.addSubview(headerContainerView)" "$PAGER_FILE"; then
  echo "Pager header must be attached to PagingViewController.view." >&2
  exit 1
fi

if grep -nE "[A-Za-z0-9_]+\\.addSubview\\(headerContainerView\\)" "$PAGER_FILE" \
  | grep -v "view.addSubview(headerContainerView)"; then
  echo "Pager header must not be attached to a list/header child view." >&2
  exit 1
fi

if grep -n "headerContainerView.removeFromSuperview()" "$PAGER_FILE"; then
  echo "Pager header should remain in the root view hierarchy." >&2
  exit 1
fi

