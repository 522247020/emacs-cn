#!/usr/bin/env python3
"""Translate extracted Emacs UI strings to Chinese via Google translate.

Produces l10n/translations.jsonl  {"s": en, "t": zh, "k": kind, "ok": bool}
Resumable: already-translated strings are reused from the cache file
l10n/cache.jsonl.
"""
import os, re, sys, json, time, urllib.request, urllib.parse, random

HERE = os.path.dirname(os.path.abspath(__file__))
IN = os.path.join(HERE, 'strings.jsonl')
CACHE = os.path.join(HERE, 'cache.jsonl')
OUT = os.path.join(HERE, 'translations.jsonl')

BASE = 'https://clients5.google.com/translate_a/t'

# ---------------------------------------------------------------- protection
TOK = '\u2063'
# Format specs that consume an argument (no space flag, no bare %)
FMT_ARG = re.compile(r'%[-+#0]*[0-9]*(?:\.[0-9]+)?[a-zA-Z]')
BT_QUOTE = re.compile(r'`[^`\']*\'')      # `symbol'  (Emacs quoting)
CMD_SUBST = re.compile(r'\\\\?[\[{][^\]}]*[\]}]')  # \[...\] \{...\}
KEYSEQ = re.compile(r'(?:(?:[CMsHAS]-)+[A-Za-z0-9/<>|~!@#$%^&*()_+{}:"]+'
                    r'|\b(?:RET|TAB|SPC|DEL|ESC|BS|LFD|NUL|HOME|END|'
                    r'PRIOR|NEXT|UP|DOWN|LEFT|RIGHT|F[0-9]{1,2})\b)')
# Isolated single letters: keybindings or variables, never translate them.
# Do not match the article "a"/"A" or the pronoun "I".
_TOK_RE = re.escape(TOK)
SINGLE_LETTER = re.compile(
    r'(?<![\w\-])(?<!' + _TOK_RE + r')([A-Za-z])(?![\w\-])(?!' + _TOK_RE + r')')
ABBREV = re.compile(r'\b(?:e\.g|i\.e|etc|vs|cf|approx)\.')
FMT_TOK = re.compile(TOK + r'F(\d+)' + TOK)
OTH_TOK = re.compile(TOK + r'O(\d+)' + TOK)
PCT_TOK = TOK + 'P' + TOK
NL_TOK = TOK + 'N' + TOK
TB_TOK = TOK + 'T' + TOK
SP_TOK = TOK + 'S' + TOK


def protect(s, doc=False):
    fmt = []
    other = []

    # 1. Protect format specs first, assigning argument positions in
    #    order of appearance.  Doing this before protecting quoted
    #    spans ensures specs inside `...' are numbered correctly.
    #    Docstrings are plain text, not format strings, so leave their
    #    percent signs alone.
    if not doc:
        s = s.replace('%%', PCT_TOK)

        def repl_fmt(m):
            fmt.append(m.group(0))
            return TOK + 'F' + str(len(fmt) - 1) + TOK

        s = FMT_ARG.sub(repl_fmt, s)

    # 2. Preserve layout characters.
    s = s.replace('\n', NL_TOK).replace('\t', TB_TOK)
    if s.startswith(' '):
        s = SP_TOK + s[1:]
    if s.endswith(' '):
        s = s[:-1] + SP_TOK

    # 3. Protect quoted symbols, command substitutions and key sequences
    #    (these may now contain format tokens, which is fine).
    def repl_other(m):
        other.append(m.group(0))
        return TOK + 'O' + str(len(other) - 1) + TOK

    s = BT_QUOTE.sub(repl_other, s)
    s = CMD_SUBST.sub(repl_other, s)
    s = KEYSEQ.sub(repl_other, s)

    # 4. Protect common Latin abbreviations as whole tokens.
    s = ABBREV.sub(repl_other, s)

    # 5. Protect isolated single letters used as keybindings/variables.
    def repl_letter(m):
        if m.group(1) in ('a', 'A', 'I'):
            return m.group(0)
        other.append(m.group(0))
        return TOK + 'O' + str(len(other) - 1) + TOK

    s = SINGLE_LETTER.sub(repl_letter, s)
    return s, other, fmt


def restore(s, other, fmt):
    # Restore protected spans first: they may (re)introduce format tokens.
    def repl_other(m):
        i = int(m.group(1))
        return other[i] if 0 <= i < len(other) else m.group(0)
    s = OTH_TOK.sub(repl_other, s)

    def repl_fmt(m):
        i = int(m.group(1))
        if i >= len(fmt):
            return m.group(0)
        return '%' + str(i + 1) + '$' + fmt[i][1:]
    s = FMT_TOK.sub(repl_fmt, s)
    s = s.replace(PCT_TOK, '%%')
    s = s.replace(NL_TOK, '\n').replace(TB_TOK, '\t').replace(SP_TOK, ' ')
    return s


def restored_other(s, other):
    """Expand O tokens in S (so hidden F tokens become visible)."""
    def repl_other(m):
        i = int(m.group(1))
        return other[i] if 0 <= i < len(other) else m.group(0)
    return OTH_TOK.sub(repl_other, s)


def fmt_specs(s):
    """Return list of format specs with argument positions normalised."""
    return FMT_ARG.findall(s)


def fmt_ok(src, trans, other, fmt):
    """True if every format placeholder appears exactly once in trans."""
    if not fmt:
        # no format args; just make sure no stray placeholders
        return True
    expanded = restored_other(trans, other)
    found = [int(m.group(1)) for m in FMT_TOK.finditer(expanded)]
    return sorted(found) == list(range(len(fmt)))


# ---------------------------------------------------------------- translate
def translate_batch(qs, tries=6):
    params = [('client', 'dict-chrome-ex'), ('sl', 'en'), ('tl', 'zh-CN')]
    params += [('q', q) for q in qs]
    url = BASE + '?' + urllib.parse.urlencode(params)
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.loads(r.read().decode('utf-8'))
            if isinstance(data, list) and len(data) == len(qs):
                return data
            time.sleep(1 + attempt)
        except Exception as e:
            time.sleep(1.5 * (attempt + 1))
    return None


def chunk(items, maxlen=1800, maxn=45):
    cur, ln = [], 0
    for it in items:
        l = len(it)
        if cur and (ln + l > maxlen or len(cur) >= maxn):
            yield cur
            cur, ln = [], 0
        cur.append(it)
        ln += l
    if cur:
        yield cur


# manual overrides for high-frequency terms where MT is poor
OVERRIDE = {
    'Quit': '退出',
    'Mark set': '已设置标记',
    'Beginning of buffer': '缓冲区开头',
    'End of buffer': '缓冲区末尾',
    'Kill buffer': '关闭缓冲区',
    'Kill buffer...': '关闭缓冲区…',
    'Open file': '打开文件',
    'Open File...': '打开文件…',
    'Open file...': '打开文件…',
    'Save buffer': '保存缓冲区',
    'Save Buffer': '保存缓冲区',
    'Save Buffer...': '保存缓冲区…',
    'Search forward': '向前搜索',
    'Search backward': '向后搜索',
    'Undo': '撤销',
    'Cut': '剪切',
    'Copy': '复制',
    'Paste': '粘贴',
    'Select All': '全选',
    'Find': '查找',
    'Find...': '查找…',
    'Replace': '替换',
    'Replace...': '替换…',
    'Customize': '自定义',
    'Options': '选项',
    'Help': '帮助',
    'Tools': '工具',
    'File': '文件',
    'Edit': '编辑',
    'View': '视图',
    'Buffers': '缓冲区',
    'Window': '窗口',
    'Search': '搜索',
    'Cancel': '取消',
    'OK': '确定',
    'Yes': '是',
    'No': '否',
    'Apply': '应用',
    'Reset': '重置',
    'Search failed': '搜索失败',
    'Read-only buffer': '只读缓冲区',
    'Buffer is read-only': '缓冲区是只读的',
    'No match': '无匹配',
}


def main():
    items = [json.loads(l) for l in open(IN, encoding='utf-8')]
    todo = [it for it in items]
    results = {}
    if os.path.exists(CACHE):
        for l in open(CACHE, encoding='utf-8'):
            try:
                r = json.loads(l)
                results[r['s']] = r
            except Exception:
                pass
    remaining = [it for it in todo if it['s'] not in results]
    print('total', len(todo), 'cached', len(results), 'remaining', len(remaining),
          file=sys.stderr)

    cachef = open(CACHE, 'a', encoding='utf-8')

    # Build one task per string; docstrings are translated as plain text.
    tasks = []
    for it in remaining:
        doc = it.get('k') in ('doc', 'docraw')
        if doc and len(it['s']) > 6000:
            continue  # too long for one request; leave untranslated
        p, other, fmt = protect(it['s'], doc)
        # Skip very long docstrings (usually mode key listings): they batch
        # poorly and are of little value.
        if doc and len(p) > 5000:
            continue
        tasks.append([it, p, other, fmt, doc])

    batches = []
    cur, ln = [], 0
    for t in tasks:
        l = len(t[1])
        if cur and (ln + l > 5000 or len(cur) >= 30):
            batches.append(cur)
            cur, ln = [], 0
        cur.append(t)
        ln += l
    if cur:
        batches.append(cur)

    done = 0
    for batch in batches:
        qs = [t[1] for t in batch]
        outs = translate_batch(qs)
        if outs is None:
            print('BATCH FAILED', qs[:1], file=sys.stderr)
            continue
        for t, o in zip(batch, outs):
            it, p, other, fmt, doc = t
            ok = fmt_ok(it['s'], o, other, fmt)
            t2 = restore(o, other, fmt) if ok else it['s']
            rec = {'s': it['s'], 't': t2, 'k': it['k'], 'ok': ok}
            results[it['s']] = rec
            cachef.write(json.dumps(rec, ensure_ascii=False) + '\n')
        cachef.flush()
        done += len(batch)
        if done % 500 < 31:
            print('done', done, '/', len(remaining), file=sys.stderr)
        time.sleep(random.uniform(0.15, 0.4))
    cachef.close()

    # apply overrides
    for s, t in OVERRIDE.items():
        if s in results:
            results[s] = {'s': s, 't': t, 'k': results[s]['k'], 'ok': True}
        else:
            results[s] = {'s': s, 't': t, 'k': 'override', 'ok': True}

    with open(OUT, 'w', encoding='utf-8') as f:
        for s in sorted(results):
            f.write(json.dumps(results[s], ensure_ascii=False) + '\n')
    bad = [r for r in results.values() if not r['ok']]
    print('wrote', len(results), 'bad-fmt', len(bad), file=sys.stderr)


if __name__ == '__main__':
    main()
