"""Supplementary candidate-file scan. Not a substitute for human provenance review."""
import re, subprocess, sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
paths=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=root).decode().split('\0')
patterns=[rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',rb'\bgh[pousr]_[A-Za-z0-9]{30,}\b',rb'\bgithub_pat_[A-Za-z0-9_]{30,}\b',rb'\bAKIA[A-Z0-9]{16}\b',rb'\bsk-[A-Za-z0-9]{30,}\b']
failures=[]; count=0
for name in sorted(set(paths)):
    if not name: continue
    p=root/name
    if p.is_symlink(): failures.append((name,'symlink')); continue
    if not p.is_file(): continue
    count+=1
    if name.startswith('MeetingTranscriber-iPad/') or name.endswith(('.zip','.p12','.p8','.mobileprovision','.m4a','.caf')) or p.name=='.env': failures.append((name,'restricted artifact'))
    data=p.read_bytes()
    if any(re.search(pattern,data) for pattern in patterns): failures.append((name,'possible credential'))
for name,reason in failures: print(f'FAIL {name}: {reason}')
print(f'Scanned {count} candidate files; {len(failures)} findings. Manual content/provenance review still required.')
sys.exit(bool(failures))
