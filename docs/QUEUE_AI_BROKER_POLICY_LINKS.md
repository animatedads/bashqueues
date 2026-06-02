# queue AI broker policy links

0.18.80 adds explicit regulatory and corporate policy-link evidence to AI broker decisions.

The AI broker still selects providers/models from local policy and registry evidence. It now also carries references to the policies that influenced or should be reviewed for the decision.

## Profile policy references

AI profile files may declare policy references:

```sh
AI_REGULATORY_POLICY_REFS="UK_GDPR|UK GDPR data protection review|policy://regulatory/uk-gdpr"
AI_CORPORATE_POLICY_REFS="CORP_AI_USE|Corporate AI acceptable-use policy|policy://corporate/ai-use"
AI_PRIVACY_POLICY_REFS="PII_REDACTION|PII redaction required before cloud AI|policy://privacy/pii-redaction"
AI_DATA_RESIDENCY_POLICY_REFS="DATA_RESIDENCY_REVIEW|Data residency review required for cloud providers|policy://data-residency/default"
AI_EXPORT_CONTROL_POLICY_REFS="EXPORT_CONTROL_REVIEW|Export-control/ITAR review before restricted content leaves boundary|policy://export-control/default"
AI_AUDIT_POLICY_REFS="AI_AUDIT_REQUIRED|AI broker request and selection audit required|policy://audit/ai-broker"
```

Each entry uses:

```text
ID|label|URI
```

Multiple entries may be separated by spaces or commas. The URI may be an internal policy URI, document locator, ticketing-system policy reference, or site-local governance identifier. The broker records the link; it does not claim external regulatory compliance by itself.

## Provider and model policy references

Provider registry entries may also include `policy_refs` at provider or model level:

```json
{
  "provider": "anthropic",
  "policy_refs": {
    "regulatory": [
      {"id":"CLOUD_AI_REVIEW","label":"Cloud AI provider review","uri":"policy://regulatory/cloud-ai-review"}
    ],
    "data_residency": [
      {"id":"DATA_RESIDENCY_REVIEW","label":"Cloud data residency review","uri":"policy://data-residency/default"}
    ]
  },
  "models": [
    {
      "name": "claude-default",
      "policy_refs": {
        "privacy": [
          {"id":"PII_REDACTION","label":"PII redaction required before cloud AI","uri":"policy://privacy/pii-redaction"}
        ]
      }
    }
  ]
}
```

Supported categories are:

```text
regulatory
corporate
privacy
data_residency
export_control
audit
```

## Broker output

`queue ai explain`, `queue ai chat`, and `queue ai json` include:

```json
"policy_links": {
  "applicable": true,
  "profile": {"regulatory": []},
  "provider": {"regulatory": []},
  "model": {"privacy": []},
  "combined": {"regulatory": [], "corporate": [], "privacy": [], "data_residency": [], "export_control": [], "audit": []}
}
```

This lets users and auditors answer:

```text
Which corporate policy caused this profile/provider to be acceptable?
Which regulatory or data-residency review applies to this cloud AI selection?
Which audit policy required evidence for this brokerage decision?
```

## Boundaries

Policy links are evidence references. They are not a compliance certification. The broker remains fail-closed for provider/model selection, but external policy approval, legal review, and corporate governance remain site-local responsibilities unless a future policy provider explicitly automates them.
