#!/usr/bin/env python3
"""Extract user-visible strings from Emacs Lisp and C sources.

Outputs:
  l10n/strings.txt   one JSON object per line: {"s": "...", "k": "menu|msg|prompt|c"}
  l10n/strings.tsv   same, tab separated (for convenience)
"""
import os, re, sys, json

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)            # /home/mhwy/Code/emacs
SRC = os.path.join(ROOT, 'src')          # /home/mhwy/Code/emacs/src

STR = r'"(?:[^"\\]|\\.)*"'

MENU_PATTERNS = [
    re.compile(r'\(menu-item\s+(' + STR + r')'),
    re.compile(r"'menu-item\s+(" + STR + r')'),
    re.compile(r'\(menu-item\s+\(purecopy\s+(' + STR + r')\)'),
    re.compile(r'\(make-sparse-keymap\s+(' + STR + r')'),
    re.compile(r':label\s+(' + STR + r')'),
    re.compile(r':help\s+(' + STR + r')'),
    re.compile(r':tag\s+(' + STR + r')'),
    re.compile(r':button\s*\(' + STR),          # not used, skip
]
# tool-bar / tab-bar items may use (tool-bar-item "..." ...)
TOOLBAR = re.compile(r'\(tool-bar-item\s+(' + STR + r')')

# additional UI-bearing forms
EXTRA_LISP = [
    re.compile(r'\(define-error\s+\(?\'?[^\s()]+\'?\s+(' + STR + r')'),
    re.compile(r"'error-message\s+(" + STR + r')'),
    re.compile(r'\(insert-button\s+(' + STR + r')'),
    re.compile(r'\(insert-text-button\s+(' + STR + r')'),
    re.compile(r'\(substitute-command-keys\s+(' + STR + r')'),
]

# C: define_error (SYM, "msg", ...) -- string is not immediately after (
C_DEFINE_ERROR = re.compile(r'define_error\s*\(\s*[^,()]+,\s*(' + STR + r')')
C_PUT_ERROR = re.compile(r'PUT_ERROR\s*\([^,]+,[^,]*,\s*(' + STR + r')')
C_PURE_STRING = re.compile(r'build_pure_c_string\s*\(\s*(' + STR + r')')

MSG_FUNCS = ['message', 'error', 'user-error', 'warn', 'y-or-n-p',
             'yes-or-no-p', 'message-box', 'format-prompt', 'format-message']

PROMPT_FUNCS = ['read-string', 'read-from-minibuffer', 'read-buffer',
                'read-file-name', 'read-directory-name', 'read-number',
                'read-regexp', 'read-command', 'read-shell-command',
                'read-passwd', 'read-answer', 'read-multiple-choice',
                'completing-read', 'format-prompt', 'read-color',
                'read-key-sequence-vector', 'read-quoted-char', 'read-key']

def func_rx(names):
    return [re.compile(r'\(' + re.escape(n) + r'\s+(' + STR + r')') for n in names]

MSG_PATTERNS = func_rx(MSG_FUNCS)
PROMPT_PATTERNS = func_rx(PROMPT_FUNCS)

# C function calls whose first string literal is user-visible
C_FUNCS = ['message', 'message1', 'message1_nolog', 'message_with_string',
           'error', 'user_error', 'signal_error', 'xFatalError', 'verror',
           'image_error', 'report_file_error', 'report_file_notify_error',
           'Ferror', 'xsignal1', 'xsignal2', 'xsignal3', 'Fsignal',
           'syms_of_', 'Fmessage']
C_PATTERN = re.compile(r'\b(' + '|'.join(C_FUNCS) + r')\s*\(\s*(' + STR + r')')
# Any call that looks like a user message
C_MSG_CALL = re.compile(r'\b(message|message1|message1_nolog|error|user_error|'
                        r'signal_error|xFatalError|image_error|Ferror)\s*\(')
C_STR = re.compile(STR)

def unescape(s):
    """s includes surrounding double quotes (Lisp or C)."""
    body = s[1:-1]
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c == '\\' and i + 1 < len(body):
            n = body[i+1]
            if n == 'n':
                out.append('\n'); i += 2; continue
            if n == 't':
                out.append('\t'); i += 2; continue
            if n == '\\':
                out.append('\\'); i += 2; continue
            if n == '"':
                out.append('"'); i += 2; continue
            if n == '=':
                out.append('\\='); i += 2; continue
            if n == "'":
                out.append("\\'"); i += 2; continue
            # leave unknown escapes as-is
            out.append('\\' + n); i += 2; continue
        out.append(c); i += 1
    return ''.join(out)

def extract_splash(src):
    """Extract string literals from the fancy splash text constants."""
    for var in ('fancy-startup-text', 'fancy-about-text'):
        m = re.search(r'\(defconst\s+' + re.escape(var) + r'\b', src)
        if not m:
            continue
        start = m.end()
        depth, i, instr = 1, start, False
        while i < len(src) and depth > 0:
            c = src[i]
            if instr:
                if c == '\\':
                    i += 2
                    continue
                if c == '"':
                    instr = False
            else:
                if c == '"':
                    instr = True
                elif c == '(':
                    depth += 1
                elif c == ')':
                    depth -= 1
            i += 1
        block = src[start:i - 1]
        for sm in re.finditer(STR, block):
            yield 'msg', unescape(sm.group(0))


def extract_macro_strings(src):
    """Collect strings passed to menu-building macros."""
    macros = ('menu-bar-make-mm-toggle', 'menu-bar-make-toggle',
              'menu-bar-make-toggle-command')
    for mac in macros:
        for m in re.finditer(r'\(\s*' + re.escape(mac) + r'\b', src):
            start = m.end()
            depth, i, instr = 1, start, False
            while i < len(src) and depth > 0:
                c = src[i]
                if instr:
                    if c == '\\':
                        i += 2
                        continue
                    if c == '"':
                        instr = False
                else:
                    if c == '"':
                        instr = True
                    elif c == '(':
                        depth += 1
                    elif c == ')':
                        depth -= 1
                i += 1
            block = src[start:i - 1]
            for sm in re.finditer(STR, block):
                yield 'menu', unescape(sm.group(0))


def extract_lisp(path):
    try:
        src = open(path, encoding='utf-8', errors='replace').read()
    except Exception:
        return
    for rx in MENU_PATTERNS[:-1]:
        for m in rx.finditer(src):
            yield 'menu', unescape(m.group(1))
    for m in TOOLBAR.finditer(src):
        yield 'menu', unescape(m.group(1))
    for rx in EXTRA_LISP:
        for m in rx.finditer(src):
            yield 'msg', unescape(m.group(1))
    for rx in MSG_PATTERNS:
        for m in rx.finditer(src):
            yield 'msg', unescape(m.group(1))
    for rx in PROMPT_PATTERNS:
        for m in rx.finditer(src):
            yield 'prompt', unescape(m.group(1))
    yield from extract_splash(src)
    yield from extract_macro_strings(src)

def extract_c(path):
    try:
        src = open(path, encoding='utf-8', errors='replace').read()
    except Exception:
        return
    for m in C_PATTERN.finditer(src):
        yield 'c', unescape(m.group(2))
    for m in C_DEFINE_ERROR.finditer(src):
        yield 'c', unescape(m.group(1))
    for m in C_PUT_ERROR.finditer(src):
        yield 'c', unescape(m.group(1))
    for m in C_PURE_STRING.finditer(src):
        yield 'c', unescape(m.group(1))

def iter_lisp():
    for sub in ['lisp', 'leim']:
        base = os.path.join(SRC, sub)
        for dp, dn, fn in os.walk(base):
            if os.sep + '.git' in dp:
                continue
            for f in fn:
                if f.endswith('.el') and not f.startswith('chinese-l10n'):
                    yield os.path.join(dp, f)

def iter_c():
    base = os.path.join(SRC, 'src')
    for f in os.listdir(base):
        if f.endswith('.c'):
            yield os.path.join(base, f)


# UI-heavy files whose *entire* string contents are worth translating.
UI_FILES = {
    'help.el', 'help-fns.el', 'help-mode.el', 'dired.el', 'dired-aux.el',
    'cus-edit.el', 'cus-theme.el', 'wid-edit.el', 'package.el',
    'tabulated-list.el', 'info.el', 'warnings.el', 'simple.el',
    'menu-bar.el', 'startup.el', 'subr.el', 'files.el', 'replace.el',
    'isearch.el', 'window.el', 'frame.el', 'faces.el', 'misc.el',
    'bookmark.el', 'proced.el', 'recentf.el', 'which-key.el',
}


def extract_ui_file(src):
    for m in re.finditer(STR, src):
        s = unescape(m.group(0))
        # Broad extraction: skip multi-line code fragments.
        if '\n' in s or '\t' in s:
            continue
        yield 'msg', s


def read_docstrings():
    """Read the runtime-extracted full docstrings (RS-separated)."""
    path = os.path.join(HERE, 'docstrings.txt')
    if not os.path.exists(path):
        return
    data = open(path, encoding='utf-8').read()
    for s in data.split('\x1e'):
        if s.strip():
            yield s


def read_docstrings_raw():
    """Read the runtime-extracted RAW docstrings (RS-separated)."""
    path = os.path.join(HERE, 'docstrings-raw.txt')
    if not os.path.exists(path):
        return
    data = open(path, encoding='utf-8').read()
    for s in data.split('\x1e'):
        if s.strip():
            yield s


def read_extra():
    """Read supplemental string lists (docstrings, Doom descriptions)."""
    for fname in ('docfirst-list.txt', 'doom-desc.txt'):
        path = os.path.join(HERE, fname)
        if not os.path.exists(path):
            continue
        for line in open(path, encoding='utf-8'):
            s = line.rstrip('\n')
            if s.strip():
                yield 'msg', s

def is_bad(s):
    if not s or s.strip() == '':
        return True
    if '\x00' in s:
        return True
    # 跳过已经含中文的串（无需翻译；也避免“中→中”链式词条）
    if re.search(r'[\u4e00-\u9fff]', s):
        return True
    # Skip regexp-ish strings.
    if re.search(r"\\[()|_<>{}[\]'=]", s):
        return True
    if ('\n' in s or '\t' in s) and len(s) > 80:
        return True
    if len(s) > 200:
        return True
    # pure format spec / punctuation-only strings
    stripped = re.sub(r'%[-+ #0-9.$]*[a-zA-Z%]', '', s).strip()
    if stripped == '':
        return True
    # must contain at least one ASCII letter
    if not re.search(r'[A-Za-z]', s):
        return True
    return False

def main():
    seen = {}
    def add(kind, s):
        if is_bad(s):
            return
        if s not in seen:
            seen[s] = kind
        elif seen[s] != 'menu' and kind == 'menu':
            # prefer menu classification
            seen[s] = 'menu'
    for p in iter_lisp():
        for kind, s in extract_lisp(p):
            add(kind, s)
        if os.path.basename(p) in UI_FILES:
            try:
                src = open(p, encoding='utf-8', errors='replace').read()
            except Exception:
                src = ''
            for kind, s in extract_ui_file(src):
                add(kind, s)
    for p in iter_c():
        for kind, s in extract_c(p):
            add(kind, s)
    for kind, s in read_extra():
        add(kind, s)
    # Docstrings bypass the usual filters (they are multi-line prose).
    for s in read_docstrings():
        if s not in seen:
            seen[s] = 'doc'
    for s in read_docstrings_raw():
        if s not in seen:
            seen[s] = 'docraw'

    items = sorted(seen.items())
    with open(os.path.join(HERE, 'strings.jsonl'), 'w', encoding='utf-8') as f:
        for s, k in items:
            f.write(json.dumps({'s': s, 'k': k}, ensure_ascii=False) + '\n')
    with open(os.path.join(HERE, 'strings.tsv'), 'w', encoding='utf-8') as f:
        for s, k in items:
            f.write(k + '\t' + s.replace('\t', '\\t') + '\n')
    from collections import Counter
    print('total', len(items), Counter(seen.values()))

if __name__ == '__main__':
    main()
