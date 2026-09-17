#!/bin/bash
# archive.sh - 正典归档压缩（百万字长篇规模管理）
# 用途：一卷完结后，把已闭合/已兑现/已揭示的旧正典条目移入 archive，保持活跃正典精简。
#       防止 500 章后 canon jsonl 无限膨胀撑爆 P2.5 上下文预算。
# 用法:
#   bash scripts/archive.sh {卷号} {卷末章号}              # 归档第 NN 卷
#   bash scripts/archive.sh --dry-run {卷号} {卷末章号}     # 只预览，不实际移动
# 保留规则（活跃区）：
#   - promises: status=pending（未回收伏笔）
#   - payoffs : status=pending（未兑现爽点/期待感）
#   - mysteries: revealed_chapter=null（未揭示谜题）
#   - roles   : 全部保留（配角池小且写前常查）
#   - 其余章号 > 卷末章的条目
# 归档区保留原始条目副本 + 生成 summary.md 卷摘要，供跨卷反查。

set -u
DRY=0; VOL="$1"; END="$2"
if [ "$1" = "--dry-run" ]; then DRY=1; VOL="$2"; END="$3"; fi
if [ -z "${VOL:-}" ] || [ -z "${END:-}" ]; then
  echo "用法: bash scripts/archive.sh [--dry-run] {卷号} {卷末章号}"
  exit 2
fi

ROOT=$(pwd)
CANON="$ROOT/追踪/canon"
ARC="$CANON/archive/卷${VOL}"
[ "$DRY" = "1" ] && echo "▶ DRY-RUN（不实际移动、不创建文件）"
if [ "$DRY" != "1" ]; then mkdir -p "$ARC"; fi

# Python 解释器探测（跨平台：python3 / python 均可）
PY="python"
command -v python3 >/dev/null 2>&1 && PY="python3"
# 强制 UTF-8 输出，避免 Windows GBK 控制台下 UnicodeEncodeError
export PYTHONIOENCODING=utf-8

"$PY" - "$CANON" "$ARC" "$END" "$VOL" "$DRY" <<'PY'
import json,sys,os
canon,arc,end,vol,dry=sys.argv[1],sys.argv[2],int(sys.argv[3]),sys.argv[4],sys.argv[5]=='1'
# 各账本的活跃保留策略
keep_all    = {'settings','roles'}                                   # 场景注册表/配角池：全留（小且常查）
keep_rule   = {                                                        # 未闭合才留
  'promises':   ('status','pending'),
  'payoffs':    ('status','pending'),
  'mysteries':  ('revealed_chapter',None),                            # None = 未揭示
}
keep_latest = {                                                        # 每实体保留最新一条（当前状态）
  'progression':   'entity',
  'relationships': ('from','to'),
  'panels':        ('entity','system','field'),
}
files=['facts','promises','progression','relationships','settings','mysteries','payoffs','panels','roles']
total_moved=0
for name in files:
    src=os.path.join(canon,name+'.jsonl')
    if not os.path.exists(src): continue
    dst=os.path.join(arc,name+'.jsonl')
    tmp=src+'.tmp'
    rows=[]; header=[]
    for l in open(src,encoding='utf-8'):
        s=l.strip()
        if not s or s.startswith('#'):
            header.append(l); continue
        try: rows.append(json.loads(s))
        except Exception: header.append(l)
    # 计算保留集
    keep=set()
    if name in keep_all:
        keep=set(range(len(rows)))
    elif name in keep_rule:
        k,v=keep_rule[name]
        for i,r in enumerate(rows):
            rv=r.get(k)
            if (v is None and rv is None) or (rv==v): keep.add(i)
    elif name=='facts':
        # facts 特殊：POV 相关秘密（known_by 非空）恒留活跃；公开事实每实体保留最新
        latest={}
        for i,r in enumerate(rows):
            v=r.get('entity'); kk=tuple(v) if isinstance(v,list) else v
            ch=r.get('chapter',0)
            try: ch=int(ch)
            except Exception: ch=-1
            if kk not in latest or ch>latest[kk][0]: latest[kk]=(ch,i)
        for i,r in enumerate(rows):
            if r.get('known_by'): keep.add(i)
        keep.update(i for ch,i in latest.values())
    elif name in keep_latest:
        keyf=keep_latest[name]
        latest={}
        for i,r in enumerate(rows):
            if isinstance(keyf,tuple):
                kk=tuple(r.get(f) for f in keyf)
            else:
                v=r.get(keyf)
                kk=tuple(v) if isinstance(v,list) else v
            ch=r.get('chapter',0)
            try: ch=int(ch)
            except Exception: ch=-1
            if kk not in latest or ch>latest[kk][0]: latest[kk]=(ch,i)
        keep={i for ch,i in latest.values()}
    # 章号 > 卷末章的也保留
    for i,r in enumerate(rows):
        ch=r.get('chapter',0)
        try: ch=int(ch)
        except Exception: ch=10**9
        if ch>end: keep.add(i)
    moved=0; kept=0
    if not dry:
        with open(dst,'w',encoding='utf-8') as dh:
            for i,r in enumerate(rows):
                if i in keep:
                    kept+=1
                else:
                    dh.write(json.dumps(r,ensure_ascii=False)+"\n"); moved+=1
        with open(tmp,'w',encoding='utf-8') as kh:
            for l in header: kh.write(l)
            for i,r in enumerate(rows):
                if i in keep:
                    kh.write(json.dumps(r,ensure_ascii=False)+"\n")
        os.replace(tmp,src)
    else:
        for i,r in enumerate(rows):
            if i in keep: kept+=1
            else: moved+=1
    total_moved+=moved
    print(f"  {name}.jsonl: 归档 {moved} 条, 活跃保留 {kept} 条")
# 卷摘要（写 summary.md）
arcfacts=os.path.join(arc,'facts.jsonl')
if os.path.exists(arcfacts) and not dry:
    facts=[json.loads(l) for l in open(arcfacts,encoding='utf-8') if l.strip() and not l.startswith('#')]
    with open(os.path.join(arc,'summary.md'),'w',encoding='utf-8') as sh:
        sh.write(f"# 卷{vol} 正典归档摘要\n\n")
        sh.write(f"- 归档事实: {len(facts)} 条\n")
        sh.write(f"- 归档截止章: ch{end}\n\n## 关键事实速览\n")
        for r in facts[:80]:
            sh.write(f"- ch{r.get('chapter')} {str(r.get('fact',''))[:70]}\n")
print(f"  总计归档 {total_moved} 条 -> {arc}")
PY

echo ""
if [ "$DRY" = "1" ]; then
  echo "预览完成。确认无误后执行: bash scripts/archive.sh $VOL $END"
else
  echo "归档完成。建议随后:"
  echo "  1) 执行快照: bash scripts/snapshot.sh $END"
  echo "  2) 更新 L2 卷摘要（若归档的是最近完结卷）"
  echo "  3) 活跃正典已精简，P2.5 加载预算恢复正常"
fi
