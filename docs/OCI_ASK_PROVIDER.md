# OCI Generative AI queue ask provider

`queue ask` supports an optional live provider named `oci`.

The provider is advisory-only. It does not execute queue commands, does not bypass policy, and does not store OCI credentials in queue audit output. It reads the normal `queue ask` provider request JSON and calls OCI Generative AI Inference with the local OCI SDK/config.

## Usage

```bash
export QUEUEBASH_AI_LIVE_ENABLED=1
queue ask --provider oci --live 'explain the waiting DB_MIGRATION jobs'
```

Optional model override:

```bash
queue ask --provider oci --model cohere.command-a-03-2025 --live 'what should I check before running this migration?'
```

## Configuration

The helper uses the OCI Python SDK and OCI config file lookup. Supported environment variables:

```text
QUEUEBASH_AI_OCI_MODEL              default: cohere.command-a-03-2025
QUEUEBASH_AI_OCI_CONFIG_FILE        optional path to OCI config file
QUEUEBASH_AI_OCI_PROFILE            optional OCI config profile, default DEFAULT
QUEUEBASH_AI_OCI_COMPARTMENT_ID     optional override; otherwise tenancy from config
QUEUEBASH_AI_OCI_ENDPOINT           optional Generative AI inference endpoint override
QUEUEBASH_AI_OCI_MAX_TOKENS         default 1500
QUEUEBASH_AI_OCI_TIMEOUT            default 120 seconds
```

`OCI_CONFIG_FILE`, `OCI_CLI_PROFILE`, and `OCI_GENAI_INFERENCE_ENDPOINT` are also recognised as fallback names.

## Helper checks

```bash
bin/queue-ai-ask-oci --self-test
queue ask provider explain oci --json
```

`--self-test` does not perform a live model call. It reports whether the helper exists, whether the OCI SDK can be imported, and whether an OCI config hint is present.

## Boundary

OCI is a live network provider, so `queue ask --provider oci --live ...` requires:

```bash
QUEUEBASH_AI_LIVE_ENABLED=1
```

If that flag is absent, Queue blocks the request before invoking the provider.
