# pol_block and security exemption audit model

`pol_block` is the terminal state for a job that is contrary to the active shared/admin class-policy statement and does not have a valid exemption.

A `pol_block` job is not retried. It does not run class claims, asset preflight, dynamic preflight, global claims, or the payload. Once an administrator issues a valid command-bound authorisation for the exact command, the job can be resubmitted.

The same valid, unexpired, command-bound authorisation may be reused for unlimited resubmissions of the exact same command hash. The user does not need to paste the code every time; the queue checks the authorisations directory for a valid matching code.

## Exemption categories

All exemptions are recorded in job files using `SECURITY_EXEMPTION_TYPE` and `SECURITY_EXEMPTION_DETAIL` where applicable.

- `policy-approved`: the shared policy grants this user or command a standing exemption.
- `description-approved`: the active policy permits a user-supplied reason as the approval mechanism.
- `code-approved`: a command-bound authorisation code approved the exemption.

For high-risk policy blocks, use `CLASS_POLICY_BLOCK_CLASS_REQUIRE="authorisation"` so a mere reason cannot approve the job.
