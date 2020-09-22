;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Jason Zeng"
      user-mail-address "zrzeng@gmail.com")

;;(setq doom-leader-alt-key "M-SPC"
;;	doom-localleader-alt-key "M-SPC l")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "monospace" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)


;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
(setq-default tab-width 8)

(setq-default kill-whole-line t)
(setq-default c-tab-always-indent nil)

(defun my-open-line (linenum)
  (interactive)
  (if (> linenum 0)
      (forward-line linenum)
    (beginning-of-line-text))
  (open-line 1))

(defun my-open-next-line ()
  (interactive)
  (my-open-line 1)
  )

(defun my-open-prev-line ()
  (interactive)
  (my-open-line -1)
  )

(defun my-kill-line ()
  (interactive)
  (move-beginning-of-line nil)
  (kill-line)
  )

(defun ccls-references-read ()
      (interactive)
      (lsp-ui-peek-find-custom "textDocument/references"
       (plist-put (lsp--text-document-position-params) :role 16)))


(global-set-key (kbd "C-M-o") (quote my-open-prev-line))
(global-set-key (kbd "C-o") (quote my-open-next-line))
(global-set-key (kbd "C-k") (quote my-kill-line))
(global-set-key (kbd "C-x C-b") (quote ivy-switch-buffer))
(global-set-key (kbd "C-x C-_") (quote counsel-grep-or-swiper))
(global-set-key (kbd "C-x C-f") (quote projectile-find-file))

(defvar my-mark-list ())

(defun marker-is-point-p (marker)
  "test if marker is current point"
  (and (eq (marker-buffer marker) (current-buffer))
       (= (marker-position marker) (point))))

(defun my-push-mark ()
  (interactive)
  (unless (and my-mark-list
               (marker-is-point-p (car my-mark-list)))
    (let (m)
      (setq m (make-marker))
      (set-marker m (point) (current-buffer))
      (push m my-mark-list))))

(defun my-pop-mark ()
  (interactive)
  (if my-mark-list
    (let* ((marker (pop my-mark-list))
           (buffer (marker-buffer marker))
           (position (marker-position marker)))
      (set-buffer buffer)
      (goto-char position)
      (switch-to-buffer buffer)
      (recenter))
    (message "No more markers")))

(defun my-find-definition ()
  (interactive)
  (my-push-mark)
  (lsp-find-definition))

(defun my-jump-backward ()
  (interactive)
  (my-pop-mark))

(add-hook 'prog-mode-hook
	(lambda ()
		(local-set-key (kbd "C-]") (quote my-find-definition))
		(local-set-key (kbd "M-SPC s") (quote lsp-ui-find-workspace-symbol))
		(local-set-key (kbd "C-t") (quote my-jump-backward))
		(local-set-key (kbd "C-r") (quote lsp-ui-peek-find-references))))

(defcustom my-make-option "-j8"
	   "Specify kernel make options")

(defun resolve-project-root (srcfile)
  (interactive)
  (let ((path (file-name-directory srcfile)))
    (while (and (not (file-exists-p (concat path ".git")))
                (not (equal path "/")))
      (setq path (file-name-directory (directory-file-name path))))
    path))

(defun my-compile-kernel ()
  (interactive)
  (let (proj-root)
    (setq proj-root (resolve-project-root buffer-file-name))
    (setq default-directory proj-root)
    (setq compile-command (format "make %s" my-make-option))
    (compile compile-command)))

(defun my-compile-c-file ()
  (interactive)
  (let* ((srcfile buffer-file-name)
	 (proj-root (resolve-project-root srcfile))
	 (objfile (file-relative-name srcfile proj-root)))
    (setq default-directory proj-root)
    (setq compile-command (format "make %s.o" (file-name-sans-extension objfile)))
    (compile compile-command)))

(defun my/highlight-pattern-in-text (pattern line)
      (when (> (length pattern) 0)
        (let ((i 0))
         (while (string-match pattern line i)
           (setq i (match-end 0))
           (add-face-text-property (match-beginning 0) (match-end 0) 'isearch t line))
         line)))

    (after! lsp-mode
      ;;; Override
      ;; This deviated from the original in that it highlights pattern appeared in symbol
      (defun lsp--symbol-information-to-xref (pattern symbol)
       "Return a `xref-item' from SYMBOL information."
       (let* ((location (gethash "location" symbol))
              (uri (gethash "uri" location))
              (range (gethash "range" location))
              (start (gethash "start" range))
              (name (gethash "name" symbol)))
         (xref-make (format "[%s] %s"
                            (alist-get (gethash "kind" symbol) lsp--symbol-kind)
                            (my/highlight-pattern-in-text (regexp-quote pattern) name))
                    (xref-make-file-location (string-remove-prefix "file://" uri)
                                             (1+ (gethash "line" start))
                                             (gethash "character" start)))))

      (cl-defmethod xref-backend-apropos ((_backend (eql xref-lsp)) pattern)
        (let ((symbols (lsp--send-request (lsp--make-request
                                           "workspace/symbol"
                                           `(:query ,pattern)))))
          (mapcar (lambda (x) (lsp--symbol-information-to-xref pattern x)) symbols))))
