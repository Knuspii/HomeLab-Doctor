#!/usr/bin/env bash
# Quality Check for server-vibecheck.sh

shellcheck \
-o require-variable-braces \
-o quote-safe-variables \
-o require-double-brackets \
-o check-unassigned-uppercase \
server-vibecheck.sh
