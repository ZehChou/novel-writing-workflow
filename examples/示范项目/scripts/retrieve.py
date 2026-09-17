#!/usr/bin/env python3
"""BM25 检索工具（离线 / 零依赖）。

P4 反查（recall）与 --dedup（dedup）共用。无持久索引：现读 L1 brief 文件，
内存建 BM25。单一事实源 = brief 文件本身，canon 改动下次自然生效。

用法:
  recall:  python3 scripts/retrieve.py recall --query 大纲/05_细纲.md \
              --current-nn 09 --top-k 3 [--briefs-dir 正文/摘要]
  dedup:   python3 scripts/retrieve.py dedup --chapter 正文/09_x.md \
              --current-nn 09 --n 3 --threshold 0.5 [--briefs-dir 正文/摘要]

分词: 默认 CJK 字符 bigram（零依赖、零启动）。env JIEBA=1 且已装 jieba 时用 jieba。
退出码: 0=通过/无命中, 1=dedup 命中(疑似重复), 2=错误。
"""
import sys
import os
import re
import math
import argparse

_CJK = re.compile(r'[\u4e00-\u9fff]')
_SPLIT = re.compile(r'[^\w\u4e00-\u9fff]+', re.UNICODE)


def _bigrams(s):
    return [s[i:i + 2] for i in range(len(s) - 1)]


def tokenize(text):
    text = text or ''
    if os.environ.get('JIEBA') == '1':
        try:
            import jieba
            return [t for t in jieba.cut(text) if t.strip()]
        except Exception:
            pass
    toks = []
    for seg in _SPLIT.split(text):
        seg = seg.strip()
        if not seg:
            continue
        if _CJK.search(seg):
            toks.extend(_bigrams(seg))
        else:
            toks.extend(seg.lower().split())
    return toks


class BM25:
    """内联 BM25（k1/b 可调）。scores() 仅按 query 词是否出现计分。"""

    def __init__(self, docs, k1=1.5, b=0.75):
        self.docs = docs
        self.k1, self.b = k1, b
        self.N = len(docs)
        self.dl = [len(d) for d in docs]
        self.avgdl = (sum(self.dl) / self.N) if self.N else 0.0
        self.df = {}
        self.tf = []
        for d in docs:
            f = {}
            for t in d:
                f[t] = f.get(t, 0) + 1
            self.tf.append(f)
            for t in f:
                self.df[t] = self.df.get(t, 0) + 1
        self.idf = {t: math.log(1 + (self.N - df + 0.5) / (df + 0.5))
                    for t, df in self.df.items()}

    def scores(self, query):
        q = set(query)
        out = [0.0] * self.N
        if not self.N:
            return out
        for i in range(self.N):
            tfi = self.tf[i]
            dl = self.dl[i] or 1
            denom_base = self.k1 * (1 - self.b + self.b * dl / (self.avgdl or 1))
            s = 0.0
            for t in q:
                f = tfi.get(t)
                if not f:
                    continue
                idf = self.idf.get(t)
                if not idf:
                    continue
                s += idf * (f * (self.k1 + 1)) / (f + denom_base)
            out[i] = s
        return out


def list_briefs(briefs_dir, current_nn, recent_n=None):
    """枚举 {NN}_*.brief.md（chapter < current）。
    recent_n=None -> 全部历史（recall）；recent_n=N -> 最近 N 章（dedup）。"""
    cur = int(current_nn)
    items = []
    if not os.path.isdir(briefs_dir):
        return items
    for name in os.listdir(briefs_dir):
        m = re.match(r'(\d+)_.*\.brief\.md$', name)
        if not m:
            continue
        nn = int(m.group(1))
        if nn >= cur:
            continue
        path = os.path.join(briefs_dir, name)
        try:
            with open(path, encoding='utf-8') as fh:
                text = fh.read()
        except Exception:
            continue
        items.append((nn, path, text))
    items.sort(key=lambda x: x[0])
    if recent_n is not None and recent_n > 0:
        items = items[-recent_n:]
    return items


def _read(path):
    if path == '-' or not path:
        return sys.stdin.read()
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def cmd_recall(args):
    query = _read(args.query)
    briefs = list_briefs(args.briefs_dir, args.current_nn, recent_n=None)
    if not briefs:
        print('(无历史 brief 可召回)', file=sys.stderr)
        return 0
    bm = BM25([tokenize(b[2]) for b in briefs])
    scores = bm.scores(tokenize(query))
    order = sorted(range(len(briefs)), key=lambda i: scores[i], reverse=True)
    mx = max(scores) if scores else 0.0
    shown = 0
    for i in order:
        if shown >= args.top_k or scores[i] <= 0:
            break
        norm = (scores[i] / mx) if mx > 0 else 0.0
        print(f"{briefs[i][0]:02d}\t{norm:.2f}\t{briefs[i][1]}")
        shown += 1
    return 0


def cmd_dedup(args):
    chapter = _read(args.chapter)
    briefs = list_briefs(args.briefs_dir, args.current_nn, recent_n=args.n)
    if not briefs:
        print('无历史 brief 可对比，跳过查重')
        return 0
    doc_toks = [tokenize(b[2]) for b in briefs]
    bm = BM25(doc_toks)
    chap_scores = bm.scores(tokenize(chapter))
    flagged = []
    print(f'对比 {len(briefs)} 篇 brief:')
    for i, (nn, _path, _txt) in enumerate(briefs):
        self_score = bm.scores(doc_toks[i])[i]  # brief 自评 = 该 brief 可达上限
        norm = (chap_scores[i] / self_score) if self_score > 0 else 0.0
        mark = '  ⚠ 高度相似' if norm >= args.threshold else ''
        print(f"  {nn:02d}  norm={norm:.2f}{mark}")
        if norm >= args.threshold:
            flagged.append(nn)
    if flagged:
        print('RESULT: 疑似重复 (' + ', '.join(f'{n:02d}' for n in flagged) + ')')
        return 1
    print('RESULT: 无高度相似章')
    return 0


def main():
    ap = argparse.ArgumentParser(description='BM25 检索（P4 反查 + --dedup）')
    sub = ap.add_subparsers(dest='cmd', required=True)

    pr = sub.add_parser('recall', help='P4 反查：召回相关历史 brief')
    pr.add_argument('--query', required=True, help='查询文件路径，或 - 读 stdin')
    pr.add_argument('--current-nn', required=True, help='当前章号（如 09）')
    pr.add_argument('--top-k', type=int, default=3)
    pr.add_argument('--briefs-dir', default='正文/摘要')
    pr.set_defaults(func=cmd_recall)

    pd = sub.add_parser('dedup', help='--dedup：当前正文 vs 最近 N 章 brief')
    pd.add_argument('--chapter', required=True)
    pd.add_argument('--current-nn', required=True)
    pd.add_argument('--n', type=int, default=3, help='回看章数（复用 跨章查重回看章数）')
    pd.add_argument('--threshold', type=float, default=0.5)
    pd.add_argument('--briefs-dir', default='正文/摘要')
    pd.set_defaults(func=cmd_dedup)

    args = ap.parse_args()
    try:
        return args.func(args)
    except Exception as e:
        print(f'ERROR: {e}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
