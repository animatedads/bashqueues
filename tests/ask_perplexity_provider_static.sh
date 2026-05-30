#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f bin/queue-ai-ask-perplexity ]]
[[ -x bin/queue-ai-ask-perplexity ]]
[[ -f providers.d/ask/perplexity.sh ]]
[[ -f docs/ASK_PERPLEXITY_PROVIDER.md ]]
[[ -f policies.d/ask/perplexity.env.example ]]
[[ -f examples/providers/ai/perplexity.env.example ]]

grep -q 'perplexity' queuebash.sh
grep -q 'queue-ai-ask-perplexity' queuebash.sh
grep -q 'QUEUEBASH_AI_PERPLEXITY_API_KEY_FILE' bin/queue-ai-ask-perplexity
grep -q 'PERPLEXITY_API_KEY' bin/queue-ai-ask-perplexity
grep -q 'https://api.perplexity.ai/chat/completions' bin/queue-ai-ask-perplexity
python3 -m py_compile bin/queue-ai-ask-perplexity
bash -n providers.d/ask/perplexity.sh
