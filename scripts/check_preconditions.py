#!/usr/bin/env python3
import argparse, hashlib, json, pathlib, sys
ap=argparse.ArgumentParser(); ap.add_argument('manifest'); ap.add_argument('target'); ap.add_argument('--json',action='store_true'); ns=ap.parse_args()
data=json.loads(pathlib.Path(ns.manifest).read_text()); target=pathlib.Path(ns.target)
def md5_file(path):
 h=hashlib.md5()
 with open(path,'rb') as f:
  for c in iter(lambda:f.read(1024*1024), b''): h.update(c)
 return h.hexdigest()
results=[]
for e in data.get('entries',[]):
 rel=e['relpath']; path=target/rel; old=e.get('file_old_md5'); new=e.get('file_new_md5')
 r={'relpath':rel,'change_type':e.get('change_type'),'status':'unknown','detail':''}
 if rel=='.queuebash/dev/scratchpad.json':
  r.update(status='ready_scratchpad_item_merge' if path.exists() else 'ready_scratchpad_create', detail='scratchpad item-level merge')
 elif old is None:
  if not path.exists(): r.update(status='ready_new_file_absent', detail='target absent')
  else:
   cur=md5_file(path)
   if cur==new: r.update(status='already_applied', detail='new file already has expected md5')
   else: r.update(status='conflict_existing_new_file', detail=f'target exists with md5 {cur}; expected absent or {new}')
 elif not path.exists(): r.update(status='missing_target', detail='target missing')
 else:
  cur=md5_file(path)
  if cur==old: r.update(status='ready_file_baseline', detail='baseline md5 matched')
  elif cur==new: r.update(status='already_applied', detail='target already has expected new md5')
  else: r.update(status='conflict_file_baseline', detail=f'expected {old}; got {cur}')
 results.append(r)
summary={'total':len(results),'ready':sum(1 for r in results if r['status'].startswith('ready_')),'already_applied':sum(1 for r in results if r['status']=='already_applied'),'conflict':sum(1 for r in results if r['status'].startswith('conflict_')),'missing':sum(1 for r in results if r['status']=='missing_target'),'scratchpad_item_merge':sum(1 for r in results if r['status'].startswith('ready_scratchpad_')),'requires_full_file_reconciliation':sum(1 for r in results if r['status'].startswith('conflict_'))}
out={'schema':'queuebash.dev_patchset.preconditions.v1','status':'ok' if summary['conflict']==0 and summary['missing']==0 else 'failed','summary':summary,'results':results}
if ns.json: print(json.dumps(out,sort_keys=True,separators=(',',':')))
else:
 print('Patchset precondition summary: '+', '.join(f'{k}={v}' for k,v in summary.items()))
 for r in results: print(f"{r['status']}\t{r['relpath']}\t{r['detail']}")
sys.exit(0 if out['status']=='ok' else 1)
