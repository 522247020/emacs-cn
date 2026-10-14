;;; chinese-l10n.el --- Chinese localization of the Emacs user interface  -*- lexical-binding: t; coding: utf-8; -*-

;; Copyright (C) 2026 Free Software Foundation, Inc.

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This library turns the visible part of the Emacs user interface
;; into Simplified Chinese.  It translates:
;;
;;   * echo-area messages and error messages (via the `chinese-l10n-table'
;;     variable, which is consulted by the C implementation of `message',
;;     `format-message' and error signalling);
;;   * minibuffer prompts;
;;   * menu-bar, tool-bar and pop-up menu items, together with their
;;     `:help' tool tips.
;;
;; Function and command names, key bindings and Lisp symbols are left
;; untouched on purpose: only human-readable text is translated.
;;
;; The actual translation data live in `chinese-l10n-data.el', a large
;; vector of alternating English and Chinese strings.  Users may extend
;; or override translations with `chinese-l10n-add-translations'.

;;; Code:

(defgroup chinese-l10n nil
  "Chinese localization of the Emacs user interface."
  :group 'environment
  :version "31.1")

(defcustom chinese-l10n-enable t
  "Whether to translate the Emacs user interface into Chinese.
When nil, the interface stays in English even though the translation
table is still loaded."
  :type 'boolean
  :group 'chinese-l10n)

(defvar chinese-l10n-table nil
  "Hash table mapping English user-interface strings to Chinese.
This variable is consulted directly by the C implementation of
`message', `format-message' and error signalling, as well as by the
Lisp code in this file.  It is normally built from `chinese-l10n-data'
by `chinese-l10n-build-table'.")

(defvar chinese-l10n-data nil
  "Vector of alternating English and Chinese UI strings.
Even-numbered elements are English keys, odd-numbered elements their
Chinese translations.")

(defun chinese-l10n-build-table (&optional data)
  "Populate `chinese-l10n-table' from DATA.
DATA defaults to `chinese-l10n-data' and must be a vector of
alternating English and Chinese strings."
  (let* ((data (or data chinese-l10n-data))
         (n (and data (length data)))
         (table (make-hash-table :test #'equal :size (or n 100))))
    (let ((i 0))
      (while (and n (< i n))
        (let ((en (aref data i))
              (zh (aref data (1+ i))))
          (when (and (stringp en) (stringp zh) (not (equal en zh)))
            (puthash en zh table))
          (setq i (+ i 2)))))
    (setq chinese-l10n-table table)
    table))

(defun chinese-l10n-translate (string)
  "Return the Chinese translation of STRING, or STRING itself.
STRING may be any object; non-strings are returned unchanged."
  (if (and chinese-l10n-enable
           (stringp string)
           (hash-table-p chinese-l10n-table))
      (or (gethash string chinese-l10n-table) string)
    string))

(defun chinese-l10n-add-translations (alist)
  "Add translations from ALIST, a list of (ENGLISH . CHINESE) pairs.
Existing entries are overridden."
  (unless (hash-table-p chinese-l10n-table)
    (chinese-l10n-build-table))
  (dolist (cell alist)
    (when (and (consp cell) (stringp (car cell)) (stringp (cdr cell)))
      (puthash (car cell) (cdr cell) chinese-l10n-table)))
  chinese-l10n-table)

;;; Minibuffer prompts

(defconst chinese-l10n-prompt-functions
  '(read-from-minibuffer
    read-string
    read-buffer
    read-file-name
    read-directory-name
    read-number
    read-regexp
    read-command
    read-shell-command
    read-color
    completing-read
    format-prompt)
  "Functions whose first argument is a prompt to translate.")

(defun chinese-l10n--translate-prompt-args (args)
  "Translate the prompt (first element) in ARGS."
  (if (and args (stringp (car args)))
      (cons (chinese-l10n-translate (car args)) (cdr args))
    args))

(defun chinese-l10n--setup-prompts ()
  (dolist (fun chinese-l10n-prompt-functions)
    (when (fboundp fun)
      (advice-add fun :filter-args #'chinese-l10n--translate-prompt-args))))

;;; Menus

(defun chinese-l10n--translate-menu-item (item)
  "Translate the label and :help of the `menu-item' list ITEM in place."
  (when (and (consp item) (eq (car item) 'menu-item))
    ;; (menu-item LABEL BINDING . PLIST)
    (let ((label (nth 1 item)))
      (when (stringp label)
        (setcar (cdr item) (chinese-l10n-translate label))))
    (let ((plist (nthcdr 3 item)))
      (while (and (consp plist) (cdr plist))
        (when (eq (car plist) :help)
          (when (stringp (cadr plist))
            (setcar (cdr plist) (chinese-l10n-translate (cadr plist)))))
        (setq plist (cddr plist))))))

(defun chinese-l10n--translate-keymap (keymap seen)
  "Translate menu items in KEYMAP recursively.  SEEN avoids cycles."
  (when (and (keymapp keymap) (not (gethash keymap seen)))
    (puthash keymap t seen)
    (condition-case nil
        (map-keymap
         (lambda (_event def)
           (cond
            ;; Top-level menu bar entries: ("File" . KEYMAP)
            ((and (consp def) (stringp (car def)))
             (setcar def (chinese-l10n-translate (car def)))
             (when (keymapp (cdr def))
               (chinese-l10n--translate-keymap (cdr def) seen)))
            ((and (consp def) (eq (car def) 'menu-item))
             (chinese-l10n--translate-menu-item def)
             ;; Recurse into a submenu keymap stored as the binding.
             (let ((binding (nth 2 def)))
               (cond
                ((keymapp binding)
                 (chinese-l10n--translate-keymap binding seen))
                ((and (consp binding) (keymapp (cdr binding)))
                 (chinese-l10n--translate-keymap (cdr binding) seen)))))
            ((keymapp def)
             (chinese-l10n--translate-keymap def seen))))
         keymap)
      (error nil))))

(defun chinese-l10n-translate-all-menus ()
  "Translate every menu item in the currently defined keymaps."
  (let ((seen (make-hash-table :test #'eq)))
    (chinese-l10n--translate-keymap (current-global-map) seen)
    (chinese-l10n--translate-keymap (current-local-map) seen)
    (dolist (sym '(menu-bar tool-bar-map tab-bar-map))
      (when (and (boundp sym) (keymapp (symbol-value sym)))
        (chinese-l10n--translate-keymap (symbol-value sym) seen)))
    (mapatoms
     (lambda (sym)
       (when (and (boundp sym) (keymapp (symbol-value sym)))
         (chinese-l10n--translate-keymap (symbol-value sym) seen))))))

(defvar chinese-l10n--menu-timer nil)

(defun chinese-l10n--schedule-menus (&rest _ignore)
  "Arrange to translate menus on the next idle moment."
  (unless (and (timerp chinese-l10n--menu-timer)
               (memq chinese-l10n--menu-timer timer-list))
    (setq chinese-l10n--menu-timer
          (run-with-idle-timer 0.3 nil #'chinese-l10n-translate-all-menus))))

(defun chinese-l10n--setup-menus ()
  (add-hook 'after-load-functions #'chinese-l10n--schedule-menus)
  (chinese-l10n-translate-all-menus))

;;; Error-message symbols

(defun chinese-l10n--translate-error-symbols ()
  "Translate the `error-message' property of defined error symbols."
  (mapatoms
   (lambda (sym)
     (let ((msg (get sym 'error-message)))
       (when (and (stringp msg)
                  (not (get sym 'chinese-l10n-translated)))
         (let ((zh (chinese-l10n-translate msg)))
           (when (not (equal zh msg))
             (put sym 'error-message zh)
             (put sym 'chinese-l10n-translated t))))))))

;;; Splash screen

(defun chinese-l10n--translate-splash-list (lst)
  "Translate strings inside the splash-screen list LST.
Function values (lambdas) are left untouched."
  (mapcar
   (lambda (x)
     (cond
      ((stringp x) (chinese-l10n-translate x))
      ((and (consp x) (not (functionp x)))
       (chinese-l10n--translate-splash-list x))
      (t x)))
   lst))

(defun chinese-l10n--translate-splash ()
  "Translate the text of the startup and about screens."
  (dolist (sym '(fancy-startup-text fancy-about-text))
    (when (boundp sym)
      (set-default sym (chinese-l10n--translate-splash-list (symbol-value sym))))))

(defun chinese-l10n--splash-insert-args (args)
  "Translate the string arguments of `fancy-splash-insert'."
  (mapcar (lambda (x) (if (stringp x) (chinese-l10n-translate x) x)) args))

(defun chinese-l10n--setup-splash ()
  (when (fboundp 'fancy-splash-insert)
    (advice-add 'fancy-splash-insert :filter-args
                #'chinese-l10n--splash-insert-args)))

;;; Widgets and buttons

(defun chinese-l10n--translate-widget-args (args)
  "Translate string values that follow a :tag keyword in widget ARGS."
  (let ((out nil) (rest args) (translate-next nil))
    (while rest
      (let ((x (pop rest)))
        (if translate-next
            (progn (push (chinese-l10n-translate x) out)
                   (setq translate-next nil))
          (push x out)
          (when (eq x :tag) (setq translate-next t)))))
    (nreverse out)))

(defun chinese-l10n--translate-first-arg (args)
  "Translate the first string argument in ARGS (a button label)."
  (if (and args (stringp (car args)))
      (cons (chinese-l10n-translate (car args)) (cdr args))
    args))

(defun chinese-l10n--setup-widgets ()
  (when (fboundp 'widget-create)
    (advice-add 'widget-create :filter-args
                #'chinese-l10n--translate-widget-args))
  (dolist (fun '(insert-button insert-text-button make-text-button))
    (when (fboundp fun)
      (advice-add fun :filter-args #'chinese-l10n--translate-first-arg))))

;;; Completion annotations (M-x / which-key)

(defun chinese-l10n--translate-wk-desc (args)
  "Translate the description argument of `which-key--propertize-description'."
  (if (and args (stringp (car args)))
      (let* ((desc (car args))
             (prefix (if (string-prefix-p "group:" desc) "group:" ""))
             (body (substring desc (length prefix)))
             (zh (chinese-l10n-translate body)))
        (cons (concat prefix zh) (cdr args)))
    args))

(defun chinese-l10n--wk-propertize (text source)
  "Propertize TEXT with the face of SOURCE, if any."
  (if (and (stringp source) (> (length source) 0)
           (get-text-property 0 'face source))
      (propertize text 'face (get-text-property 0 'face source))
    text))

(defun chinese-l10n--wk-maybe-add-docstring (current original)
  "Chinese version of `which-key--maybe-add-docstring'.
For a command that has no custom description, show the first line of
its (already translated) docstring instead of its English name."
  (let* ((orig-sym (and (stringp original) (intern-soft original)))
         (doc (and orig-sym (commandp orig-sym)
                   (ignore-errors (documentation orig-sym))))
         (first (and (stringp doc) (car (split-string doc "\n"))))
         (zh-first (if (stringp first)
                       (or (and (hash-table-p chinese-l10n-table)
                                (gethash first chinese-l10n-table))
                           first)
                     first))
         (custom (and (stringp current) orig-sym
                      (not (equal current (symbol-name orig-sym)))
                      t)))
    (cond
     ((eq which-key-show-docstrings 'docstring-only)
      (or (and zh-first (chinese-l10n--wk-propertize zh-first current))
          current ""))
     (which-key-show-docstrings
      (cond ((and current zh-first)
             (format "%s %s" current
                     (chinese-l10n--wk-propertize zh-first current)))
            (zh-first (chinese-l10n--wk-propertize zh-first current))
            (t (or current ""))))
     (custom (or current ""))
     ((and zh-first (not (equal zh-first (symbol-name orig-sym))))
      (chinese-l10n--wk-propertize zh-first current))
     (t (or current "")))))

(defconst chinese-l10n--which-key-prefixes
  '(("C-x 4" . "其他窗口")
    ("C-x 5" . "框架")
    ("C-x 6" . "两列")
    ("C-x 8" . "Unicode")
    ("C-x RET" . "编码/输入")
    ("C-x C-k" . "键盘宏")
    ("C-x C-k C-r" . "宏环")
    ("C-x C-k C-q" . "宏计数器")
    ("C-x a" . "缩写")
    ("C-x n" . "缩窄")
    ("C-x r" . "寄存器/矩形/书签")
    ("C-x t" . "标签页")
    ("C-x v" . "版本控制")
    ("C-x w" . "高亮")
    ("C-x x" . "缓冲区")
    ("C-x p" . "项目")
    ("C-x @" . "事件")
    ("C-x C-v" . "访问文件")
    ("C-x =" . "比较")
    ("C-h 4" . "其他窗口帮助")
    ("M-s h" . "高亮匹配")
    ("M-g" . "跳转")
    ("M-s" . "搜索")
    ("C-c ^" . "排序"))
  "Chinese names for common key prefix maps shown by which-key.")

(defun chinese-l10n--setup-which-key-prefixes ()
  (dolist (cell chinese-l10n--which-key-prefixes)
    (ignore-errors
      (which-key-add-key-based-replacements (car cell) (cdr cell)))))

(defun chinese-l10n--translate-column (col)
  "Translate the name of a `tabulated-list-format' column COL."
  (cond
   ((vectorp col)
    (if (and (> (length col) 0) (stringp (aref col 0)))
        (let ((copy (copy-sequence col)))
          (aset copy 0 (chinese-l10n-translate (aref col 0)))
          copy)
      col))
   ((consp col)
    (if (stringp (car col))
        (cons (chinese-l10n-translate (car col)) (cdr col))
      col))
   (t col)))

(defun chinese-l10n--tabulated-list-format (fmt)
  "Return FMT with translated column names."
  (cond
   ((vectorp fmt)
    (apply #'vector
           (mapcar #'chinese-l10n--translate-column (append fmt nil))))
   ((consp fmt)
    (mapcar #'chinese-l10n--translate-column fmt))
   (t fmt)))

(defun chinese-l10n--tabulated-list-around (orig)
  "Translate `tabulated-list-format' around ORIG."
  (let ((tabulated-list-format
         (chinese-l10n--tabulated-list-format tabulated-list-format)))
    (funcall orig)))

(defun chinese-l10n--translate-doc (doc)
  "Translate a documentation string DOC if a translation exists."
  (if (and (stringp doc) (hash-table-p chinese-l10n-table))
      (or (gethash doc chinese-l10n-table) doc)
    doc))

(defun chinese-l10n--doc-lookup (rawdoc res raw)
  "Translate RAWDOC, substituting keys unless RAW.
RES is the already-substituted original, used as a fallback key."
  (if (not (hash-table-p chinese-l10n-table))
      res
    (let* ((sub (and (stringp rawdoc) (not (equal rawdoc res))
                     (ignore-errors (substitute-command-keys rawdoc))))
           (zh (or (gethash res chinese-l10n-table)
                   (and (stringp rawdoc) (gethash rawdoc chinese-l10n-table))
                   (and sub (gethash sub chinese-l10n-table)))))
      (cond
       ((not zh) res)
       (raw zh)
       (t (or (ignore-errors (substitute-command-keys zh)) zh))))))

(defun chinese-l10n--documentation-around (orig sym &optional raw)
  "Translate `documentation' output, handling raw and substituted forms."
  (let ((res (funcall orig sym raw)))
    (if (not (stringp res))
        res
      (chinese-l10n--doc-lookup (ignore-errors (funcall orig sym t)) res raw))))

(defun chinese-l10n--documentation-property-around (orig sym prop &optional raw)
  "Translate `documentation-property' output."
  (let ((res (funcall orig sym prop raw)))
    (if (not (stringp res))
        res
      (chinese-l10n--doc-lookup (ignore-errors (funcall orig sym prop t))
                                res raw))))

(defun chinese-l10n--translate-map-title (title)
  "Translate a binding-help section TITLE."
  (if (not (stringp title))
      title
    (let ((zh (and (hash-table-p chinese-l10n-table)
                   (gethash title chinese-l10n-table))))
      (cond
       (zh zh)
       ((string-match " Minor Mode Bindings\\'" title)
        (concat (substring title 0 (match-beginning 0)) " 次模式绑定"))
       ((string-match " Major Mode Bindings\\'" title)
        (concat (substring title 0 (match-beginning 0)) " 主模式绑定"))
       ((string-match "Property Bindings\\'" title)
        (concat (substring title 0 (match-beginning 0)) "属性绑定"))
       (t title)))))

(defun chinese-l10n--describe-map-tree-args (args)
  "Translate the TITLE argument of `help--describe-map-tree'."
  (let ((args (copy-sequence args)))
    (when (and (> (length args) 4) (stringp (nth 4 args)))
      (setcar (nthcdr 4 args) (chinese-l10n--translate-map-title (nth 4 args))))
    args))

(defun chinese-l10n--setup-documentation ()
  "Translate the output of `documentation' and `documentation-property'.
This makes `C-h f', `C-h v', `C-h k', `C-h m', eldoc and help
tooltips show Chinese documentation."
  (advice-add 'documentation :around #'chinese-l10n--documentation-around)
  (advice-add 'documentation-property :around
              #'chinese-l10n--documentation-property-around)
  (advice-add 'help--describe-map-tree :filter-args
              #'chinese-l10n--describe-map-tree-args))

(defun chinese-l10n--translate-doc-first-line (doc)
  "Translate the first line of DOC, a documentation string."
  (if (stringp doc)
      (let* ((nl (string-match "\n" doc))
             (first (if nl (substring doc 0 nl) doc))
             (zh (chinese-l10n-translate first)))
        (if (equal zh first)
            doc
          (concat zh (if nl (substring doc nl) ""))))
    doc))

(defun chinese-l10n--setup-completion ()
  ;; which-key and marginalia are usually loaded lazily, so register the
  ;; advice for both the already-loaded and the not-yet-loaded cases.
  (with-eval-after-load 'which-key
    (advice-add 'which-key--propertize-description :filter-args
                #'chinese-l10n--translate-wk-desc)
    (advice-add 'which-key--maybe-add-docstring :override
                #'chinese-l10n--wk-maybe-add-docstring)
    (chinese-l10n--setup-which-key-prefixes))
  (with-eval-after-load 'marginalia
    (advice-add 'marginalia--function-doc :filter-return
                #'chinese-l10n--translate-doc-first-line))
  (with-eval-after-load 'tabulated-list
    (advice-add 'tabulated-list-init-header :around
                #'chinese-l10n--tabulated-list-around))
  (when (fboundp 'which-key--propertize-description)
    (unless (advice-member-p #'chinese-l10n--translate-wk-desc
                             'which-key--propertize-description)
      (advice-add 'which-key--propertize-description :filter-args
                  #'chinese-l10n--translate-wk-desc)))
  (when (fboundp 'which-key--maybe-add-docstring)
    (unless (advice-member-p #'chinese-l10n--wk-maybe-add-docstring
                             'which-key--maybe-add-docstring)
      (advice-add 'which-key--maybe-add-docstring :override
                  #'chinese-l10n--wk-maybe-add-docstring)))
  (when (fboundp 'marginalia--function-doc)
    (unless (advice-member-p #'chinese-l10n--translate-doc-first-line
                             'marginalia--function-doc)
      (advice-add 'marginalia--function-doc :filter-return
                  #'chinese-l10n--translate-doc-first-line))))

;;; Mode names

(defun chinese-l10n--translate-mode-name ()
  "Translate the `mode-name' of the current buffer."
  (cond
   ((stringp mode-name)
    (let ((zh (chinese-l10n-translate mode-name)))
      (unless (equal zh mode-name)
        (setq-local mode-name zh))))
   ((consp mode-name)
    (let ((zh (mapcar (lambda (x)
                        (if (stringp x) (chinese-l10n-translate x) x))
                      mode-name)))
      (unless (equal zh mode-name)
        (setq-local mode-name zh))))))

;;; Setup

;;; easy-menu（许多主模式用它，菜单在打开时才构建）

(defun chinese-l10n--easy-menu-convert (item)
  "Translate the menu item returned by `easy-menu-convert-item'.
The result is either (menu-item LABEL ...) or (KEY menu-item LABEL ...)."
  (cond
   ((and (consp item) (eq (car item) 'menu-item))
    (chinese-l10n--translate-menu-item item))
   ((and (consp item) (eq (cadr item) 'menu-item))
    (chinese-l10n--translate-menu-item (cdr item))))
  item)

(defun chinese-l10n--setup-easy-menu ()
  "Translate menus built lazily by `easy-menu-define'."
  (when (fboundp 'easy-menu-convert-item)
    (advice-add 'easy-menu-convert-item :filter-return
                #'chinese-l10n--easy-menu-convert)))

(defun chinese-l10n-setup ()
  "Enable Chinese localization of the user interface."
  (unless (hash-table-p chinese-l10n-table)
    (chinese-l10n-build-table))
  (when (and chinese-l10n-enable (not noninteractive))
    (when (boundp 'minibuffer-default-prompt-format)
      (setq minibuffer-default-prompt-format "\uff08\u9ed8\u8ba4 %s\uff09"))
    (when (boundp 'yes-or-no-prompt)
      (setq yes-or-no-prompt "\uff08\u662f\u6216\u5426\uff09 "))
    (chinese-l10n--setup-prompts)
    (chinese-l10n--setup-widgets)
    (chinese-l10n--setup-easy-menu)
    (chinese-l10n--setup-splash)
    (chinese-l10n--setup-completion)
    (chinese-l10n--setup-documentation)
    (chinese-l10n--translate-error-symbols)
    (chinese-l10n--setup-menus)
    (add-hook 'after-change-major-mode-hook #'chinese-l10n--translate-mode-name)
    (chinese-l10n--translate-mode-name)))

(load "international/chinese-l10n-data" t t)

;; The table must exist before the dump so that the C code and already
;; loaded Lisp see it; menus are translated once the real frame exists.
(chinese-l10n-build-table)
(chinese-l10n--translate-error-symbols)
(chinese-l10n--translate-splash)
(add-hook 'after-init-hook #'chinese-l10n-setup)

(provide 'chinese-l10n)
;;; chinese-l10n.el ends here
