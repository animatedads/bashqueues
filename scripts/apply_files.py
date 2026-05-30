#!/usr/bin/env python3
import argparse, datetime, hashlib, json, pathlib, shutil
ap=argparse.ArgumentParser(); ap.add_argument('manifest'); ap.add_argument('target'); ap.add_argument('files'); ap.add_argument('--backup-dir'); ap.add_argument('--json',action='store_true'); ns=ap.parse_args()
data=json.loads(pathlib.Path(ns.manifest).read_text()); target=pathlib.Path(ns.target); files=pathlib.Path(ns.files)
def md5_file(path):
 h=hashlib.md5()
 with open(path,'rb') as f:
  for c in iter(lambda:f.read(1024*1024), b''): h.update(c)
 return h.hexdigest()
def load_json(path):
 try: return json.loads(path.read_text())
 except Exception: return None
def item_key(item):
 return item.get('id') or item.get('item_id') or item.get('key') if isinstance(item,dict) else None
def merge_scratchpad(dst, src):
 incoming=load_json(src)
 if incoming is None: raise SystemExit(f'incoming scratchpad is not valid JSON: {src}')
 if not dst.exists(): dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(src,dst); return {'mode':'created','added':len(incoming.get('items',[]) if isinstance(incoming,dict) else []),'kept':0,'conflicts':0}
 current=load_json(dst)
 if current is None: raise SystemExit(f'target scratchpad is not valid JSON: {dst}')
 cur_items=current.setdefault('items',[]); inc_items=incoming.get('items',[])
 index={item_key(x):x for x in cur_items if item_key(x)}; added=kept=conflicts=0
 for item in inc_items:
  k=item_key(item)
  if not k or k not in index: cur_items.append(item); added+=1; index[k]=item; continue
  if index[k]==item: kept+=1; continue
  conflicts+=1; current.setdefault('merge_conflicts',[]).append({'id':k,'reason':'same scratchpad item id differs; kept target item','incoming':item})
 current.setdefault('merge_history',[]).append({'schema':'queuebash.dev_patchset.scratchpad_merge.v1','created_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':'patchset','added':added,'kept':kept,'conflicts':conflicts})
 dst.write_text(json.dumps(current,indent=2,sort_keys=True)+'\n'); return {'mode':'merged','added':added,'kept':kept,'conflicts':conflicts}
backup_root=pathlib.Path(ns.backup_dir) if ns.backup_dir else target/'.queuebash'/'dev'/'patchset-backups'
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
backup_dir=backup_root/f'{stamp}_{data.get("created_at","patchset").replace(":","")}'
backup_dir.mkdir(parents=True,exist_ok=True)
backup_manifest={'schema':'queuebash.dev_patchset.backup_manifest.v1','created_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'target':str(target),'backup_dir':str(backup_dir),'entries':[]}
for e in data.get('entries',[]):
 rel=e['relpath']; dst=target/rel; rec={'relpath':rel,'existed':dst.exists(),'change_type':e.get('change_type'),'action':'merge_scratchpad' if rel=='.queuebash/dev/scratchpad.json' else ('replace' if dst.exists() else 'create')}
 if dst.exists():
  rec['old_md5']=md5_file(dst); rec['old_size']=dst.stat().st_size; b=backup_dir/'files'/rel; b.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(dst,b); rec['backup_path']=str(b.relative_to(backup_dir))
 else: rec['rollback']='delete_created_file'
 backup_manifest['entries'].append(rec)
backup_manifest_path=backup_dir/'backup_manifest.json'; backup_manifest_path.write_text(json.dumps(backup_manifest,indent=2,sort_keys=True)+'\n')
applied=[]
for e in data.get('entries',[]):
 rel=e['relpath']; src=files/rel; dst=target/rel; dst.parent.mkdir(parents=True,exist_ok=True)
 if rel=='.queuebash/dev/scratchpad.json': applied.append({'relpath':rel,'status':'merged_scratchpad','result':merge_scratchpad(dst,src)}); continue
 shutil.copy2(src,dst); applied.append({'relpath':rel,'status':'applied'})
out={'schema':'queuebash.dev_patchset.apply.v1','status':'ok','backup_dir':str(backup_dir),'backup_manifest':str(backup_manifest_path),'applied':applied}
if ns.json: print(json.dumps(out,sort_keys=True,separators=(',',':')))
else:
 print(f'backup_dir: {backup_dir}')
 print(f'backup_manifest: {backup_manifest_path}')
 for a in applied: print(f"{a['status']} {a['relpath']}")
