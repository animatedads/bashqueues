# Secrets Scanner explainability

`secrets_scanner` facts are deliberately advisory. They describe provider-family posture using fixture JSON so frontends and automated tools can explain what would be inspected without reaching live systems.

The family records observed provider types, representative safe identifiers, policy posture, and explicit non-goals. Every fixture carries `live_api_used=false`, `mutated=false`, `provisioning_performed=false`, and `provider_output_is_shell=false`.
