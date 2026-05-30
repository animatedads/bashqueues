# Azure class criteria

Azure classes in this package are examples and contract templates. They document the expected provider facts and asset rails for future enforcement.

A mature Azure class should declare:

- identity/auth posture, preferably managed identity or federated identity;
- subscription and tenant expectations;
- region/sovereignty allowlist;
- storage artifact and SAS redaction posture;
- network posture such as VNet/subnet/NSG/private endpoint;
- audit evidence such as Azure Activity Log / Monitor / Defender signal pointers;
- retention/deletion evidence;
- FinOps/cost ceilings where applicable;
- legal/compliance mapping with pending-validation status unless primary-source validated.

Do not call a class Azure-compliant or first-tier merely because a class file exists. Provider contracts, fixtures, JSON contracts, explainability, and tests must agree.
