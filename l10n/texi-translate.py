#!/usr/bin/env python3
"""机器翻译 Emacs 手册（Texinfo）。

- 只翻译“人类可读文本”：正文段落、章节标题、菜单条目描述、@item 标签
- 原样保留所有 Texinfo 标记（@code{}、@xref{}、@node、@cindex 等）
- 逐段翻译（把换行折行的段落合成一段再翻，质量更好）
- 结果写到 l10n/manual-zh/<file>.texi，并带断点续传缓存

用法：
    python3 l10n/texi-translate.py [--jobs N] [--limit N]
"""
import os, re, sys, json, time, random

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, 'src', 'doc', 'emacs')
OUT = os.path.join(HERE, 'manual-zh')
CACHE = os.path.join(HERE, 'manual-cache.jsonl')

sys.path.insert(0, HERE)
from translate import translate_batch  # noqa: E402

TOK = '\u2063'
TOK_RE = re.compile(TOK + r'(\d+)' + TOK)

TITLE_CMDS = ('chapter', 'section', 'subsection', 'subsubsection',
              'unnumbered', 'unnumberedsec', 'unnumberedsubsec',
              'appendix', 'appendixsec', 'appendixsubsec',
              'heading', 'subheading', 'title', 'subtitle', 'settitle',
              'top', 'node')
TITLE_RE = re.compile(r'^(@(?:' + '|'.join(TITLE_CMDS) + r'))(?=\s|$)(.*)$')
ITEM_RE = re.compile(r'^(@itemx?)(?=\s|$)(.*)$')
MENU_ENTRY_RE = re.compile(r'^(\s*\*\s+.*?(?:::|\.)\s*)(.*)$')

VERBATIM_START = re.compile(
    r'^\s*@(example|smallexample|lisp|smalllisp|verbatim|ignore|tex|html|'
    r'iftex|ifhtml|ifxml|ifdocbook|ifplaintext|iflatex|ifnottex)\b')
VERBATIM_END = re.compile(r'^\s*@end\s+(\w+)')

# 行首为这些命令时是“结构行”（原样保留）；其余（如 @samp/@xref/@code
# 开头的续行）属于正文段落。
# 行内命令（可出现在段落中）；除此之外以 @ 开头的行都视为“结构行”。
INLINE = set("""
samp code kbd key var file env command dfn cite xref pxref ref url email w
dots enddots bullet copyright registeredsymbol today value pounds euro minus
point print equiv error expansion ctrl option abbr acronym math emph strong
sc r i b t slanted slash backslash at lbrace rbrace dotsb dotsc dotsi dotsm
dotsr dotsl dotsd dotsx indicateurl uref inlinefmt inlineraw tie
""".split())

STRUCT_RE = re.compile(r'^\s*@([a-zA-Z]+)')


def is_structural(line):
    m = STRUCT_RE.match(line)
    return bool(m) and m.group(1).lower() not in INLINE


def protect(s):
    """把 @命令（含 {...}）替换成占位符。"""
    out, store = [], []
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c == '@':
            if i + 1 < n and not s[i + 1].isalpha():
                store.append(s[i:i + 2])
                out.append(TOK + str(len(store) - 1) + TOK)
                i += 2
                continue
            k = i + 1
            while k < n and s[k].isalpha():
                k += 1
            if k < n and s[k] == '{':
                depth, kk = 0, k
                while kk < n:
                    if s[kk] == '{':
                        depth += 1
                    elif s[kk] == '}':
                        depth -= 1
                        if depth == 0:
                            kk += 1
                            break
                    kk += 1
                store.append(s[i:kk])
                out.append(TOK + str(len(store) - 1) + TOK)
                i = kk
                continue
            store.append(s[i:k])
            out.append(TOK + str(len(store) - 1) + TOK)
            i = k
            continue
        out.append(c)
        i += 1
    return ''.join(out), store


def restore(s, store):
    def repl(m):
        i = int(m.group(1))
        return store[i] if 0 <= i < len(store) else m.group(0)
    return TOK_RE.sub(repl, s)


def has_letters(s):
    return bool(re.search(r'[A-Za-z]', s))


def parse_file(path):
    """返回 pieces 列表：字符串(原样) 或 ('T', 待翻译文本元组)。

    (kind, prefix, text, suffix)：最终写回 prefix + 翻译(text) + suffix。
    """
    lines = open(path, encoding='utf-8').read().split('\n')
    pieces = []
    i, n = 0, len(lines)
    verbatim = None
    table_code = False          # @table 的参数是否为代码类
    while i < n:
        line = lines[i]
        s = line.strip()

        # ---- 退出 verbatim
        if verbatim:
            pieces.append(line)
            m = VERBATIM_END.match(line)
            if m and m.group(1) == verbatim:
                verbatim = None
            i += 1
            continue
        m = VERBATIM_START.match(line)
        if m:
            verbatim = m.group(1)
            pieces.append(line)
            i += 1
            continue

        # ---- 空行
        if s == '':
            pieces.append(line)
            i += 1
            continue

        # ---- 记录 @table 类型
        mt = re.match(r'^\s*@(table|vtable|ftable)\s+(\S+)', line)
        if mt:
            table_code = mt.group(2) in ('@code', '@kbd', '@key', '@file',
                                         '@samp', '@var', '@env', '@command')
            pieces.append(line)
            i += 1
            continue

        # ---- 标题 / 节点
        mt = TITLE_RE.match(s)
        if mt:
            if mt.group(1) == '@node':
                pieces.append(line)          # 节点名保持英文
            else:
                pieces.append(('title', mt.group(1) + ' ', mt.group(2).strip(), ''))
            i += 1
            continue

        # ---- 菜单条目：* Node:: 描述（可跨行）
        mm = MENU_ENTRY_RE.match(line)
        if mm:
            head = mm.group(1)
            desc_lines = [mm.group(2)]
            j = i + 1
            while j < n:
                nxt = lines[j]
                if nxt.strip() == '' or nxt.lstrip().startswith(('*', '@')):
                    break
                desc_lines.append(nxt.strip())
                j += 1
            desc = ' '.join(x.strip() for x in desc_lines).strip()
            if desc:
                pieces.append(('menu', head + ' ', desc, ''))
            else:
                pieces.append(head)
            i = j
            continue

        # ---- 以 @ 开头的结构命令行
        if is_structural(s):
            mi = ITEM_RE.match(s)
            if mi and not table_code:
                # @item 后是散文（@asis），翻译；代码类表格不翻
                pieces.append(('item', mi.group(1) + ' ', mi.group(2).strip(), ''))
            else:
                pieces.append(line)
            i += 1
            continue

        # ---- 正文段落：把连续非空、非结构行合成一段
        para = [line.strip()]
        j = i + 1
        while j < n:
            nxt = lines[j]
            if nxt.strip() == '' or is_structural(nxt) \
               or MENU_ENTRY_RE.match(nxt):
                break
            para.append(nxt.strip())
            j += 1
        pieces.append(('para', '', ' '.join(para), ''))
        i = j
    return pieces


def collect_tasks(src, only=None):
    tasks = []          # (file, index, kind, prefix, text, store, protected)
    files = sorted(f for f in os.listdir(src) if f.endswith('.texi')
                   and (not only or f in only))
    for fn in files:
        path = os.path.join(src, fn)
        pieces = parse_file(path)
        for idx, pc in enumerate(pieces):
            if isinstance(pc, tuple):
                kind, pre, text, suffix = pc
                if not has_letters(text):
                    continue
                prot, store = protect(text)
                if not has_letters(prot):
                    continue
                tasks.append([fn, idx, kind, pre, text, store, prot])
    return files, tasks


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', default=SRC)
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--only', default='',
                    help='逗号分隔的文件名（仅翻译这些，含所需 @include）')
    a = ap.parse_args()
    src_dir, out_dir = a.src, a.out
    only = set(x for x in a.only.split(',') if x) or None

    os.makedirs(out_dir, exist_ok=True)
    files, tasks = collect_tasks(src_dir, only)
    print('dir=%s files=%d tasks=%d' % (src_dir, len(files), len(tasks)),
          file=sys.stderr)

    cache = {}
    if os.path.exists(CACHE):
        for l in open(CACHE, encoding='utf-8'):
            try:
                r = json.loads(l)
                cache[r['s']] = r['t']
            except Exception:
                pass
    cachef = open(CACHE, 'a', encoding='utf-8')

    todo = [t for t in tasks if t[5] and t[6] not in cache and t[4] not in cache]
    # 以原文为键查缓存
    for t in tasks:
        if t[4] in cache:
            t.append(cache[t[4]])
    todo = [t for t in tasks if len(t) < 8]
    print('todo=%d cached=%d' % (len(todo), len(tasks) - len(todo)), file=sys.stderr)

    batches, cur, ln = [], [], 0
    for t in todo:
        L = len(t[6])
        if cur and (ln + L > 3500 or len(cur) >= 20):
            batches.append(cur)
            cur, ln = [], 0
        cur.append(t)
        ln += L
    if cur:
        batches.append(cur)

    done = 0
    for b in batches:
        qs = [t[6] for t in b]
        outs = translate_batch(qs)
        if outs is None:
            print('BATCH FAILED', file=sys.stderr)
            continue
        for t, o in zip(b, outs):
            txt = restore(o, t[5])
            t.append(txt)
            cachef.write(json.dumps({'s': t[4], 't': txt}, ensure_ascii=False) + '\n')
        cachef.flush()
        done += len(b)
        if done % 200 < 21:
            print('done %d/%d' % (done, len(todo)), file=sys.stderr)
        time.sleep(random.uniform(0.1, 0.3))
    cachef.close()

    # 写回文件
    byfile = {}
    for t in tasks:
        byfile.setdefault(t[0], {})[t[1]] = t
    for fn in files:
        pieces = parse_file(os.path.join(src_dir, fn))
        out = []
        for idx, pc in enumerate(pieces):
            if isinstance(pc, tuple):
                kind, pre, text, suffix = pc
                t = byfile.get(fn, {}).get(idx)
                translated = t[7] if (t and len(t) >= 8) else text
                out.append(pre + translated + suffix)
            else:
                out.append(pc)
        open(os.path.join(out_dir, fn), 'w', encoding='utf-8').write('\n'.join(out))
    print('written to', out_dir, file=sys.stderr)


if __name__ == '__main__':
    main()
