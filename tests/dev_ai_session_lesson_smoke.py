#!/usr/bin/env python3
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
import shutil
import tempfile
from pathlib import Path

root = Path(tempfile.mkdtemp())
try:
    os.environ['QUEUEBASH_ROOT'] = str(root)
    os.environ['QUEUEBASH_DEV_SCRATCHPAD'] = str(root / 'dev' / 'scratchpad.json')
    os.environ['QUEUEBASH_VERSION'] = '0.18.92'
    os.environ['QUEUEBASH_ALLOW_NONINTERACTIVE'] = '1'
    os.environ['QUEUEBASH_SCRIPT_PATH'] = str(Path.cwd() / 'queuebash.sh')

    loader = importlib.machinery.SourceFileLoader('queue_dev_ai', 'bin/queue-dev-ai')
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)

    def call(args):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = mod.main(args)
        assert rc == 0, (args, rc, buf.getvalue())
        return json.loads(buf.getvalue())

    discover = call(['discover', '--json'])
    assert discover['schema'] == 'queuebash.dev_ai.discover.v1'

    start = call(['session', 'start', '--agent', 'bob14', '--role', 'provider-family', '--task', 'lesson smoke', '--base', '0.18.88', '--json'])
    sid = start['session_id']

    queue_try = call(['try', '--session', sid, '--intent', 'dogfood read-only queue dev ai discover', '--json', '--', 'queue', 'dev', 'ai', 'discover', '--json'])
    assert queue_try['outcome'] == 'pass', queue_try
    assert 'queuebash.dev_ai.discover.v1' in queue_try.get('stdout_tail', ''), queue_try

    first_try = call(['try', '--session', sid, '--intent', 'check disk before unzip', '--json', '--', 'df', '-h', '.'])
    assert first_try['outcome'] == 'pass', first_try
    tid = first_try['try_id']

    lesson = call(['lesson', '--session', sid, '--try', tid, '--fail', '--text', 'Check disk space before unzipping archives.', '--match', 'unzip *.zip*', '--precheck', 'df -h . && unzip -l {{ZIPFILE}} | tail -1', '--json'])
    lid = lesson['lesson']['lesson_id']
    assert Path(root / 'dev' / 'ai_lessons.d' / f'{lid}.json').exists()

    lessons = call(['session', 'lessons', '--session', sid, '--json'])
    assert any(item['lesson_id'] == lid for item in lessons['lessons']), lessons

    blocked = call(['try', '--session', sid, '--intent', 'unzip archive', '--json', '--', 'unzip', 'archive.zip'])
    assert blocked['status'] == 'blocked_by_lesson', blocked
    assert lid in blocked['lesson_context']['matched'], blocked

    confirmed = call(['try', '--session', sid, '--intent', 'unzip after confirming lesson', '--confirm-lesson', lid, '--json', '--', 'unzip', 'archive.zip'])
    assert confirmed['status'] == 'ok', confirmed
    assert lid in confirmed['lesson_context']['confirmed'], confirmed
    assert confirmed['outcome'] in {'fail', 'matched_expected_error', 'pass', 'timeout'}, confirmed

    stopped = call(['session', 'stop', '--session', sid, '--status', 'done', '--summary', 'smoke complete', '--json'])
    assert stopped['session_status'] == 'done', stopped
    print('PASS dev_ai_session_lesson_smoke')
finally:
    shutil.rmtree(root, ignore_errors=True)
