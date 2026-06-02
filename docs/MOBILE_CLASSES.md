# Mobile platform class templates

Three class templates support mobile job execution:

- MOBILE_ANDROID — Android (Termux/Proot), 10% CPU cap, 128M memory, network-none sandbox
- MOBILE_IOS — iOS (ish/local shell), same caps  
- MOBILE_LOCAL_ONLY — confidential local-only, no egress, strict sandbox

## Architecture

Mobile devices use the existing queue-remote-service-client.py and queue-remote-management-listener.py for signed remote job submission. No new HTTP shim is required.

Device attestation (iOS App Attest / Android Play Integrity) tokens should be passed as QUEUEBASH_DEVICE_ATTESTATION_TOKEN in the job metadata for audit purposes.

## Egress policy

MOBILE_ANDROID and MOBILE_IOS allow global egress with encryption required.
MOBILE_LOCAL_ONLY sets CLASS_EGRESS_ALLOWED_JURISDICTION=NONE, blocking all fetch operations.
