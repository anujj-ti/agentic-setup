# noise-senders.md — Known-noise sender list
# Format: one address or domain per line. Lines starting with # are ignored.
# Domain suffix: @domain.com  |  Full address: exact@address.com
# Prefix patterns (no domain): noreply@ matches any address starting with "noreply@"
# Edit this file directly — no stow redeploy needed (D-155)

# GitHub automated notifications
@notifications.github.com
noreply@github.com
notifications@github.com

# CI/CD systems
noreply@circleci.com
builds@heroku.com
no-reply@travis-ci.com
noreply@semaphoreci.com

# Generic no-reply patterns
noreply@
no-reply@
donotreply@
do-not-reply@

# Marketing and newsletters (common SaaS)
newsletter@
digest@
updates@
marketing@

# Monitoring and alerting systems
alerts@
@pagerduty.com
@opsgenie.com
@statuspage.io

# Package registries and dependency bots
npm@npmjs.com
dependabot@github.com
renovate@whitesourcesoftware.com
