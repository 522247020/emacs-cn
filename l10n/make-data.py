#!/usr/bin/env python3
"""Generate lisp/international/chinese-l10n-data.el from translations."""
import os, json, sys, re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TARGETS = [
    os.path.join(ROOT, 'src', 'lisp', 'international', 'chinese-l10n-data.el'),
]

# Fixes applied to every translation, to normalise recurring machine
# translation mistakes.
POST_FIX = [
    ('\u7f13\u51b2\u5668', '\u7f13\u51b2\u533a'),          # buffer
    ('\u6740\u6b7b\u7f13\u51b2\u533a', '\u5173\u95ed\u7f13\u51b2\u533a'),
    ('\u6740\u6b7b\u8fdb\u7a0b', '\u7ec8\u6b62\u8fdb\u7a0b'),
    ('\u5f00\u5173\u7f13\u51b2\u533a', '\u5207\u6362\u7f13\u51b2\u533a'),
    ('\u8f83\u5dee\u7684', '\u5b50'),
    ('\u8f83\u5dee', '\u5b50'),
    ('\u53e3\u8bd1\u5458', '\u89e3\u91ca\u5668'),
]


def post_fix(t):
    for a, b in POST_FIX:
        t = t.replace(a, b)
    return t

# A valid format directive: %% or [%][N$][flags][width][.prec]conv
DIRECTIVE = re.compile(r'%(?:\d+\$)?[-+#0]*\d*(?:\.\d+)?[a-zA-Z]')


def bad_percent(t):
    """True if T contains a stray % that `format' cannot handle."""
    tmp = t.replace('%%', '')
    tmp = DIRECTIVE.sub('', tmp)
    return '%' in tmp

# Hand-written translations for strings that the extractor does not see
# (splash screen, echo-area hints, and a few important terms).
MANUAL = {
    'Welcome to ': '欢迎使用 ',
    ', one component of the ': '，它是 ',
    ' operating system.\\n\\n': ' 操作系统的一个组件。\\n\\n',
    ' operating system.\\n': ' 操作系统的组件。\\n',
    'Emacs Tutorial': 'Emacs 教程',
    '\\tLearn basic keystroke commands': '\\t学习基本按键命令',
    '\\tLearn basic Emacs keystroke commands': '\\t学习基本的 Emacs 按键命令',
    'Emacs Guided Tour': 'Emacs 导览',
    'Browse https://www.gnu.org/software/emacs/': '浏览 https://www.gnu.org/software/emacs/',
    'Browse https://www.gnu.org/software/emacs/tour/': '浏览 https://www.gnu.org/software/emacs/tour/',
    'Browse https://www.gnu.org/gnu/linux-and-gnu.html': '浏览 https://www.gnu.org/gnu/linux-and-gnu.html',
    'Browse https://www.gnu.org/gnu/thegnuproject.html': '浏览 https://www.gnu.org/gnu/thegnuproject.html',
    '\\tOverview of Emacs features at gnu.org\\n': '\\t在 gnu.org 上概览 Emacs 功能\\n',
    '\\tSee an overview of Emacs features at gnu.org\\n': '\\t在 gnu.org 上概览 Emacs 功能\\n',
    'View Emacs Manual': '查看 Emacs 手册',
    '\\tView the Emacs manual using Info\\n': '\\t使用 Info 查看 Emacs 手册\\n',
    'Absence of Warranty': '无担保声明',
    '\\tGNU Emacs comes with ': '\\tGNU Emacs 附带 ',
    'ABSOLUTELY NO WARRANTY\\n': '绝对无担保\\n',
    'Copying Conditions': '复制条件',
    '\\tConditions for redistributing and changing Emacs\\n': '\\t重新分发和修改 Emacs 的条件\\n',
    'Ordering Manuals': '订购手册',
    '\\tPurchasing printed copies of manuals\\n': '\\t购买印刷版手册\\n',
    '\\tBuying printed manuals from the FSF\\n': '\\t从 FSF 购买印刷版手册\\n',
    'This is ': '这是 ',
    ", a text editor and more.\\nIt's a component of the ": '，一款文本编辑器及更多。\\n它是 ',
    'Display info on the GNU project.': '显示 GNU 工程的信息。',
    'Authors': '作者',
    '\\tMany people have contributed code included in GNU Emacs\\n': '\\t许多人贡献了 GNU Emacs 中的代码\\n',
    'Contributing': '参与贡献',
    '\\tHow to report bugs and contribute improvements to Emacs\\n': '\\t如何报告缺陷并为 Emacs 贡献改进\\n',
    'GNU and Freedom': 'GNU 与自由',
    '\\tWhy we developed GNU Emacs, and the GNU operating system\\n': '\\t我们为何开发 GNU Emacs 和 GNU 操作系统\\n',
    'Getting New Versions': '获取新版本',
    '\\tHow to obtain the latest version of Emacs\\n': '\\t如何获取最新版本的 Emacs\\n',
    'Emacs Manual': 'Emacs 手册',
    '\\tDisplay the Emacs manual in Info mode': '\\t在 Info 模式下显示 Emacs 手册',
    'GNU Emacs': 'GNU Emacs',
    'GNU': 'GNU',
    'GNU/Linux': 'GNU/Linux',
    'TUTORIAL': 'TUTORIAL',
    'Info': 'Info',
    'Emacs': 'Emacs',

    # High-frequency menu / UI terms where machine translation is weak.
    'Save': '保存',
    'Save As...': '另存为…',
    'Save As': '另存为',
    'Save As…': '另存为…',
    'Save File': '保存文件',
    'Save File...': '保存文件…',
    'Save Buffer': '保存缓冲区',
    'Save Buffer...': '保存缓冲区…',
    'Save All': '全部保存',
    'Save Options': '保存选项',
    'Save Some Buffers': '保存部分缓冲区',
    'Revert': '还原',
    'Revert Buffer': '还原缓冲区',
    'Exit Emacs': '退出 Emacs',
    'Quit Emacs': '退出 Emacs',
    'Close': '关闭',
    'Close Frame': '关闭框架',
    'Delete Frame': '删除框架',
    'New File': '新建文件',
    'New Frame': '新建框架',
    'Open File...': '打开文件…',
    'Split Window': '拆分窗口',
    'Split Window Below': '在下方拆分窗口',
    'Split Window Right': '在右侧拆分窗口',
    'Delete Window': '关闭窗口',
    'Other Window': '其他窗口',
    'One Window': '单个窗口',
    'Highlight Active Region': '高亮活动区域',
    'Highlight Matching Parentheses': '高亮匹配的括号',
    'Make text in active region stand out in color (Transient Mark mode)':
        '用颜色突出显示活动区域中的文本（瞬态标记模式）',
    'Highlight matching/mismatched parentheses at cursor (Show Paren mode)':
        '高亮光标处匹配/不匹配的括号（显示括号模式）',
    'Auto Save': '自动保存',
    'Auto-Save': '自动保存',
    'Auto Fill': '自动换行',
    'Line Wrap': '自动换行',
    'Word Wrap': '自动换行',
    'Case-Insensitive Search': '不区分大小写搜索',
    'Search Forward': '向前搜索',
    'Search Backward': '向后搜索',
    'Replace': '替换',
    'Replace...': '替换…',
    'Replace String': '替换字符串',
    'Replace String...': '替换字符串…',
    'Goto Line': '转到行',
    'Go to Line': '转到行',
    'Spell-Check': '拼写检查',
    'Spell Checking': '拼写检查',
    'Spell Check': '拼写检查',
    'Wrap': '换行',
    'Untabify': '取消制表符',
    'Tabify': '转为制表符',
    'Sort Lines': '行排序',
    'Delete': '删除',
    'Delete...': '删除…',
    'Rename': '重命名',
    'Move': '移动',
    'Copy': '复制',
    'Cut': '剪切',
    'Paste': '粘贴',
    'Select All': '全选',
    'Deselect All': '取消全选',
    'Select': '选择',
    'Deselect': '取消选择',
    'Filter': '筛选',
    'Show': '显示',
    'Hide': '隐藏',
    'Refresh': '刷新',
    'Reload': '重新加载',
    'Update': '更新',
    'Add': '添加',
    'Remove': '移除',
    'Edit': '编辑',
    'View': '查看',
    'Insert': '插入',
    'Abort': '中止',
    'Cancel': '取消',
    'Apply': '应用',
    'Reset': '重置',
    'Revert...': '还原…',
    'Finish': '完成',
    'Continue': '继续',
    'Retry': '重试',
    'Ignore': '忽略',
    'None': '无',
    'Default': '默认',
    'Always': '总是',
    'Never': '从不',
    'Yes': '是',
    'No': '否',
    'OK': '确定',

    # Error signals (define_error / PUT_ERROR).
    'Wrong type argument': '类型参数错误',
    'Wrong type argument: %S, %S': '类型参数错误：%S，%S',
    'Args out of range': '参数超出范围',
    'Args out of range: %S, %S': '参数超出范围：%S，%S',
    'Invalid function': '无效函数',
    'Invalid function: %S': '无效函数：%S',
    'End of file during parsing': '解析时遇到文件结尾',
    "Symbol's value as variable is void": '符号作为变量的值为空',
    "Symbol's value as variable is void: %s": '符号作为变量的值为空：%s',
    "Symbol's function definition is void": '符号的函数定义为空',
    "Symbol's function definition is void: %s": '符号的函数定义为空：%s',
    'List contains a loop': '列表包含循环',
    'Wrong number of arguments': '参数数量错误',
    'No catch for tag': '没有对应的 catch 标签',
    'Arithmetic error': '算术错误',
    'Arithmetic domain error': '算术定义域错误',
    'Arithmetic range error': '算术范围错误',
    'Attempt to set a constant symbol': '试图设置常量符号',
    'Attempt to trap writes to a constant symbol': '试图捕获对常量符号的写入',
    'Invalid read syntax': '无效的读取语法',
    'Invalid regexp': '无效的正则表达式',
    'Invalid coding system': '无效的编码系统',
    'Wrong length argument': '长度参数错误',
    'Types do not match': '类型不匹配',
    'Buffer is read-only': '缓冲区是只读的',
    'Text is read-only': '文本是只读的',
    'Selecting deleted buffer': '选择了已删除的缓冲区',
    'User interaction while inhibited': '禁止交互时发生了用户交互',
    'No such file or directory': '没有那个文件或目录',
    'Permission denied': '权限不足',
    'File exists': '文件已存在',
    'File is missing': '文件缺失',
    'No fileset is available here': '此处没有可用的文件集',
    'Mark set': '已设置标记',
    'Mark activated': '标记已激活',
    'Mark deactivated': '标记已停用',
    'No mark set in this buffer': '此缓冲区未设置标记',
    'Beginning of buffer': '缓冲区开头',
    'End of buffer': '缓冲区末尾',
    'Search failed': '搜索失败',
    'No match': '无匹配',
    'Nothing to undo': '无可撤销操作',
    'No further undo information': '没有更多撤销信息',
    'Undo': '撤销',
    'Redo': '重做',
    'Quit': '退出',
    'Kill buffer': '关闭缓冲区',
    'Kill Buffer': '关闭缓冲区',
    'Save buffer': '保存缓冲区',
    'Open file': '打开文件',

    # Major-mode names shown in the mode line.
    'Fundamental': '基本',
    'Text': '文本',
    'Help': '帮助',
    'Messages': '消息',
    'Compilation': '编译',
    'Buffer Menu': '缓冲区菜单',
    'Completion List': '补全列表',
    'Occur': '匹配列表',
    'Apropos': '查找',
    'Custom': '自定义',
    'Customize': '自定义',
    'Isearch': '增量搜索',
    'Shell': 'Shell',
    'Dired': 'Dired',
    'Info': 'Info',
    'Org': 'Org',
    'Grep': 'Grep',
    'Warnings': '警告',
    'VC': 'VC',
    'Outline': '折叠',
    'DocView': '文档视图',
    'EWW': 'EWW',
    'Package Menu': '包菜单',
    'Emacs-Lisp': 'Emacs Lisp',
    'Lisp Interaction': 'Lisp 交互',

    # which-key labels and separators.
    'prefix': '前缀',
    'Prefix Command': '前缀命令',
    'lambda': 'lambda',
    'closure': '闭包',
    'function': '函数',
    'unknown': '未知',
    'group': '分组',
    'next-page': '下一页',
    'previous-page': '上一页',
    'undo-key': '撤销按键',
    'toggle-docstrings': '切换文档字符串',
    'help': '帮助',
    'abort': '中止',
    'digit-arg': '数字参数',
    'Actions': '操作',
    'Action': '操作',
    'Branch': '分支',
    'Agenda': '议程',

    # Keymap symbol names shown by which-key.
    'vc-prefix-map': '版本控制',
    'ctl-x-4-map': '其他窗口',
    'ctl-x-5-map': '框架',
    'ctl-x-map': 'C-x',
    'help-map': '帮助',
    'kmacro-keymap': '键盘宏',
    'tab-prefix-map': '标签页',
    'project-prefix-map': '项目',
    'mode-specific-command-prefix': '模式命令',

    # tabulated-list headers and common labels.
    'Package': '软件包',
    'Version': '版本',
    'Status': '状态',
    'Archive': '归档',
    'Description': '描述',
    'Summary': '摘要',
    'Size': '大小',
    'Mode': '模式',
    'File': '文件',
    'Name': '名称',
    'Key': '按键',
    'Binding': '绑定',
    'Command': '命令',
    'Function': '函数',
    'Variable': '变量',
    'Face': '外观',
    'Group': '分组',
    'Option': '选项',
    'Macro': '宏',
    'Special Form': '特殊形式',
    'Keymap': '键位图',
    'Symbol': '符号',
    'Library': '库',
    'Parent groups': '父分组',

    # Customize states.
    'STANDARD': '标准',
    'SAVED': '已保存',
    'CHANGED': '已更改',
    'SET': '已设置',
    'EDITED': '已编辑',
    'ROGUE': '异常',
    'THEMED': '主题',
    'UNKNOWN': '未知',
    'Not documented': '无文档',
    'Documentation:': '文档：',
    'Value:': '值：',
    'Default value': '默认值',
    'State': '状态',
    'Show Value': '显示值',
    'Show Saved Lisp Expression': '显示保存的 Lisp 表达式',

    # Binding-help section titles (see help--describe-map-tree).
    'Key translations': '按键转换',
    '\f\nOverriding Bindings': '\f\n覆盖绑定',
    '\f\nGlobal Bindings': '\f\n全局绑定',
    '\f\nFunction key map translations': '\f\n功能键映射转换',
    '\f\nInput decoding map translations': '\f\n输入解码映射转换',
    "\f\n`local-map' Property Bindings": "\f\n`local-map' 属性绑定",

    # describe-variable value labels.
    'value is': '值为',
    '\nOriginal value was \n': '\n原始值为 \n',
    'It is a terminal-local variable; ': '它是终端局部变量；',
    'globally void': '全局为空',
    'global value is ': '全局值为 ',
    'the same.': '相同。',
    '\n\nValue:': '\n\n值：',
    'value is shown ': '值显示为',
    'below': '下方',
    ' is void as a variable.': ' 作为变量为空。',
    '  This %s was introduced, or its default value was changed, in\n  version %s of Emacs.\n':
        '  此 %1$s 在 Emacs %2$s 版中引入，或其默认值发生了更改。\n',
    '  This %s was introduced, or its default value was changed, in\n  version %s of the %s package':
        '  此 %1$s 在 %3$s 包的 %2$s 版中引入，或其默认值发生了更改',
    ' that is part of Emacs %s': '，它是 Emacs %1$s 的一部分',
    'Its ': '其 ',
    'It is void as a variable.': '它作为变量为空。',
    '  You can ': '  您可以 ',
    'customize': '自定义',
    ' this variable.': '此变量。',
    'variable': '变量',
    'face': '外观',

    # help buffer metadata phrases.
    'It is bound to many ordinary text characters.\n': '它绑定到许多普通文本字符。\n',
    'Its keys are remapped to ': '其按键被重映射为 ',
    'Without this remapping, it would be bound to ': '若无此重映射，它将绑定到 ',
    'It is bound to ': '它绑定到 ',
    ', and many ordinary text characters': '，以及许多普通文本字符',
    'many ordinary text characters.': '许多普通文本字符。',
    'It ': '它',
    'could ': '可能',
    'can ': '可以',
    'also ': '也',
    'be invoked from the menu: ': '可从菜单调用： ',
    ', but that was remapped to ': '，但被重映射为 ',
    'as well.\n': '。\n',
    '\nInferred type:\n  ': '\n推断类型：\n  ',
    '%s%s runs the command %s': '%1$s%2$s 运行命令 %3$s',
    '%s%s is undefined': '%1$s%2$s 未定义',
    ' (found in %s)': '（位于 %1$s）',
    'Type \\[delete-other-windows] to delete the help window': '输入 \\[delete-other-windows] 关闭帮助窗口',
    ' is a variable defined in `%s\'.\n\n': ' 是定义于 `%1$s\' 中的变量。\n\n',
    ' defined in `%s\'.\n\n': ' 定义于 `%1$s\'。\n\n',
    'Major mode %S': '主模式 %S',
    'The major mode is ': '主模式为 ',
    ' mode': '模式',
    ' defined in %s': ' 定义于 %1$s',

    # function description header fragments.
    ' is ': ' 是 ',
    'an autoloaded ': '自动加载的 ',
    'interactive ': '交互式 ',
    'an interactive ': '一个交互式 ',
    'a ': '一个 ',
    'a keyboard macro': '一个键盘宏',
    'a reader construct': '一个读取器构造',
    'an alias for `%s\'': '`%1$s\' 的别名',
    'an autoloaded %s': '自动加载的 %1$s',
    'interactive Lisp function': '交互式 Lisp 函数',
    'keymap': '键位图',
    'Lisp macro': 'Lisp 宏',
    'Lisp function': 'Lisp 函数',
    'sparse keymap': '稀疏键位图',
    ' in `%s\'': '，位于 `%1$s\'',
    ',\nwhich is not defined.': '，\n但它未定义。',
    '\nKey             Binding\n': '\n按键            绑定\n',
    '\n  (this binding is currently shadowed)': '\n  （此绑定当前被遮蔽）',
    ', which is ': '，即 ',
    ', which is not currently defined.\n': '，它当前未定义。\n',

    # Info 阅读器 / 菜单常见项
    'Up': '向上',
    'Next': '下一个',
    'Previous': '上一个',
    'Backward': '向后',
    'Forward': '向前',
    'Beginning': '开头',
    'Top': '顶部',
    'Final Node': '末尾节点',
    'First Node': '第一个节点',
    'Go to Node...': '转到节点…',
    'Go to node...': '转到节点…',
    'Search...': '搜索…',
    'Search Next': '查找下一个',
    'Copy Node Name': '复制节点名',
    'Clone Info buffer': '克隆 Info 缓冲区',
    'Index': '索引',
    'Menu': '菜单',

    # 启动画面 / 杂项
    'Open *scratch* buffer': '打开 *scratch* 缓冲区',
    'New to Emacs?': '初次使用 Emacs？',
    'New to Emacs?  Consider enabling ': '初次使用 Emacs？  考虑启用 ',
    '  Consider enabling ': '  考虑启用 ',
    'newcomer presets': '新手预设',
    'Emacs tutorial': 'Emacs 教程',
    'Emacs manual': 'Emacs 手册',
    'Browse manuals': '浏览手册',
    'Buy manuals': '购买手册',
    'Activate menubar': '激活菜单栏',
    'Visit New File': '访问新文件',
    'Open Home Directory': '打开主目录',
    'Customize Startup': '自定义启动',
    'Open file': '打开文件',
}


def esc(s):
    """Escape a string for an Elisp double-quoted literal."""
    out = []
    for ch in s:
        if ch == '\\':
            out.append('\\\\')
        elif ch == '"':
            out.append('\\"')
        elif ch == '\n':
            out.append('\\n')
        elif ch == '\t':
            out.append('\\t')
        elif ch == '\f':
            out.append('\\f')
        elif ch == '\r':
            out.append('\\r')
        else:
            out.append(ch)
    return '"' + ''.join(out) + '"'


def main():
    data = {}
    # cache first, then the final translations (which include overrides)
    for fname in ('cache.jsonl', 'translations.jsonl'):
        path = os.path.join(HERE, fname)
        if not os.path.exists(path):
            continue
        for line in open(path, encoding='utf-8'):
            try:
                r = json.loads(line)
            except Exception:
                continue
            if r.get('ok', True) and r.get('t') and r['s'] != r['t']:
                data[r['s']] = (r['t'], r.get('k', ''))
    # manual entries win
    for k, v in MANUAL.items():
        data[k] = (v, 'manual')

    # Drop entries whose translation contains a stray '%' that would make
    # `format' fail.  Docstrings are plain text, so leave their '%' alone.
    dropped = [k for k, (v, kind) in data.items()
               if kind != 'doc' and bad_percent(v)]
    for k in dropped:
        del data[k]
    if dropped:
        print('dropped', len(dropped), 'entries with stray %', file=sys.stderr)

    # Drop Chinese-source entries (translation artefacts) and identity rows.
    items = sorted((k, post_fix(v)) for k, (v, kind) in data.items()
                   if k != v and not re.search(r'[\u4e00-\u9fff]', k))

    lines = []
    lines.append(';;; chinese-l10n-data.el --- Chinese translation data  -*- lexical-binding: t; coding: utf-8; -*-')
    lines.append('')
    lines.append(';; Generated automatically from l10n/ by make-data.py.  Do not edit.')
    lines.append('')
    lines.append(';;; Code:')
    lines.append('')
    lines.append('(setq chinese-l10n-data')
    lines.append('      [')
    for i, (k, v) in enumerate(items):
        lines.append('       ' + esc(k) + ' ' + esc(v))
    lines.append('       ])')
    lines.append('')
    lines.append('(provide \'chinese-l10n-data)')
    lines.append(';;; chinese-l10n-data.el ends here')
    lines.append('')
    with open(TARGETS[0], 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    for target in TARGETS[1:]:
        with open(target, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
    print('wrote', ', '.join(TARGETS), 'entries', len(items))


if __name__ == '__main__':
    main()
