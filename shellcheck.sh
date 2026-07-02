#!/usr/bin/env bash
# Quality Check for homelab-doctor

shellcheck \
-o require-variable-braces \
-o quote-safe-variables \
-o require-double-brackets \
-o check-unassigned-uppercase \
homelab-doctor.sh
