# Data Quality legal and compliance notes

The data_quality provider family is fixture-first and stores no secrets or live service credentials.

Compliance boundary:

- no live provider calls in default tests
- no provider state mutation
- no access grant or revocation
- no data/content reads beyond synthetic fixture metadata
- no personal data in fixtures
- no executable command output

Provider facts may support later compliance review, but they are not legal approval and do not replace site policy, data governance, export-control, or reviewer acceptance.
