# APAC/China cloud provider contracts

This package adds a contract-first APAC/China provider family for **Alibaba Cloud**, **Tencent Cloud**, and **Huawei Cloud**.

It is deliberately a fixture-first provider pack. It defines normalized JSON contracts, provider helper stubs, policy examples, class templates, fixtures, explainability notes, and tests. It does **not** perform live API calls, require credentials, provision or destroy cloud resources, mutate IAM, or refactor `queuebash.sh` dispatch.

## Providers

Provider aliases normalize to:

| Provider | Aliases |
| --- | --- |
| `alibaba` | `aliyun`, `alibaba-cloud`, `alibabacloud` |
| `tencent` | `tencent-cloud`, `qcloud` |
| `huawei` | `huawei-cloud`, `huaweicloud` |

## Schemas

Each provider uses the same check set:

```text
queuebash.apac_china.<provider>.detect.v1
queuebash.apac_china.<provider>.identity.v1
queuebash.apac_china.<provider>.region.v1
queuebash.apac_china.<provider>.compute.v1
queuebash.apac_china.<provider>.storage.v1
queuebash.apac_china.<provider>.network.v1
queuebash.apac_china.<provider>.finops.v1
queuebash.apac_china.<provider>.legal.v1
```

Provider output is constrained JSON only. It must not return shell, injected policy code, API secrets, access keys, private keys, signed URL values, console sessions, or user-data scripts.

## Default testing model

Default tests run from fixtures only:

```bash
QUEUEBASH_APAC_CHINA_FIXTURE_DIR=tests/fixtures/apac_china \
  providers.d/apac_china/apac_china_provider.sh alibaba detect
```

Live provider checks are intentionally not implemented in this contract package.

## Security rules

- No live API calls by default.
- No credentials required for tests.
- No provisioning/destruction.
- No queue dispatcher refactor.
- No access-key, secret-key, service-account, API token, private key, or signed URL values in job files or normal logs.
- Provider failures must be fail-closed for classes that declare APAC/China provider requirements.
- Compliance/legal posture is mapped pending validation; do not claim compliance or platform parity from these fixtures alone.

## Concrete fixture schemas

The shipped fixtures exercise concrete schemas such as:

```text
queuebash.apac_china.alibaba.detect.v1
queuebash.apac_china.tencent.detect.v1
queuebash.apac_china.huawei.detect.v1
```
