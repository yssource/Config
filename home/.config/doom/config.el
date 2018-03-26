;;; private/my/config.el -*- lexical-binding: t; -*-

(load! +bindings)
(load! +ui)

(def-package! avy
  :commands (avy-goto-char-timer)
  :init
  (setq avy-timeout-seconds 0.2)
  )

(after! company
  (setq company-idle-delay 0.1
        company-tooltip-limit 10
        company-minimum-prefix-length 2
        company-tooltip-minimum-width 60
        company-tooltip-margin 0
        company-tooltip-offset-display nil
        company-dabbrev-downcase nil
        company-dabbrev-ignore-case nil
        company-dabbrev-code-other-buffers t
        company-quickhelp-delay 0.1
        company-show-numbers t
        company-tooltip-align-annotations t
        company-require-match 'never
        company-frontends '(company-childframe-frontend company-echo-metadata-frontend)
        company-backends '(company-capf company-dabbrev)
        company-global-modes '(not comint-mode erc-mode message-mode help-mode gud-mode)
        company-childframe-child-frame nil))

(set! :lookup 'emacs-lisp-mode :documentation #'helpful-at-point)

(after! eshell
  (defun eshell/l (&rest args) (eshell/ls "-l" args))
  (defun eshell/e (file) (find-file file))
  (defun eshell/md (dir) (eshell/mkdir dir) (eshell/cd dir))
  (defun eshell/ft (&optional arg) (treemacs arg))

  (defun eshell/up (&optional pattern)
    (let ((p (locate-dominating-file
              (f-parent default-directory)
              (lambda (p)
                (if pattern
                    (string-match-p pattern (f-base p))
                  t)))
             ))
      (eshell/pushd p)))
  )

(remove-hook 'doom-post-init-hook #'evil-snipe-mode)

(def-package! lispy
  :hook (emacs-lisp-mode . lispy-mode)
  :config
  (setq lispy-outline "^;; \\(?:;[^#]\\|\\*+\\)"
        lispy-outline-header ";; ")
  (map! :map lispy-mode-map
        :i "C-c (" #'lispy-wrap-round
        :i "_" #'special-lispy-different
        "d" nil
        :i [remap delete-backward-char] #'lispy-delete-backward))

;; Also use lispyville in prog-mode for [ ] < >
(def-package! lispyville
  :demand t
  :after (evil)
  :hook (lispy-mode . lispyville-mode)
  :config
  (lispyville-set-key-theme
   '(operators
     c-w
     (escape insert)
     (slurp/barf-lispy)
     additional-movement))
  (map! :map emacs-lisp-mode-map
        :nm "gh" #'lispyville-left
        :nm "gl" #'lispyville-right
        :nm "J" #'lispyville-forward-sexp
        :nm "K" #'lispyville-backward-sexp
        :n "C-<left>" #'lispy-forward-barf-sexp
        :n "C-<right>" #'lispy-forward-slurp-sexp
        :n "C-M-<left>" #'lispy-backward-slurp-sexp
        :n "C-M-<right>" #'lispy-backward-barf-sexp
        :localleader
        :n "e" (λ! (save-excursion (forward-sexp) (eval-last-sexp nil)))
        )
  )

(def-package! lsp-mode
  :load-path "~/Dev/Emacs/lsp-mode"
  :defer t
  )

(def-package! lsp-ui
  :load-path "~/Dev/Emacs/lsp-ui"
  :demand t
  :hook (lsp-mode . lsp-ui-mode)
  :config
  (setq
   lsp-ui-sideline-enable nil
   lsp-ui-doc-header nil
   lsp-ui-doc-include-signature t
   lsp-ui-doc-background (doom-color 'base4)
   lsp-ui-doc-border (doom-color 'fg)

   lsp-ui-peek-expand-function (lambda (xs) (mapcar #'car xs)))

  (map! :map lsp-ui-mode-map
        :localleader
        :n "lA" #'lsp-ui-peek-find-workspace-symbol
        :n "lF" #'lsp-format-buffer
        :n "lL" #'lsp-ui-sideline-mode
        :n "lD" #'lsp-ui-doc-mode
        :n "lr" #'lsp-rename

        :n "lp" #'cquery-preprocess-file
        :n "lf" #'cquery-freshen-index
        :n "a" #'cquery/references-address
        :n "r" #'cquery/references-read
        :n "w" #'cquery/references-write
        )

   (map! :after lsp-ui-peek
         :map lsp-ui-peek-mode-map
         "h" #'lsp-ui-peek--select-prev-file
         "j" #'lsp-ui-peek--select-next
         "k" #'lsp-ui-peek--select-prev
         "l" #'lsp-ui-peek--select-next-file
         )

   (defhydra hydra/ref (evil-normal-state-map "x")
     "reference"
     ("d" lsp-ui-peek-find-definitions "next" :bind nil)
     ("j" (-let [(i . n) (lsp-ui-find-next-reference)]
            (if (> n 0) (message "%d/%d" i n))) "next")
     ("k" (-let [(i . n) (lsp-ui-find-prev-reference)]
            (if (> n 0) (message "%d/%d" i n))) "prev")
     ("R" (-let [(i . n) (lsp-ui-find-prev-reference
                          (lambda (x)
                            (/= (logand (gethash "role" x 0) 8) 0)))]
            (if (> n 0) (message "read %d/%d" i n))) "prev read" :bind nil)
     ("r" (-let [(i . n) (lsp-ui-find-next-reference
                          (lambda (x)
                            (/= (logand (gethash "role" x 0) 8) 0)))]
            (if (> n 0) (message "read %d/%d" i n))) "next read" :bind nil)
     ("W" (-let [(i . n) (lsp-ui-find-prev-reference
                          (lambda (x)
                            (/= (logand (gethash "role" x 0) 16) 0)))]
            (if (> n 0) (message "write %d/%d" i n))) "prev write" :bind nil)
     ("w" (-let [(i . n) (lsp-ui-find-next-reference
                          (lambda (x)
                            (/= (logand (gethash "role" x 0) 16) 0)))]
            (if (> n 0) (message "write %d/%d" i n))) "next write" :bind nil)
     )
   )

(defun +advice/xref-set-jump (&rest args)
  (lsp-ui-peek--with-evil-jumps (evil-set-jump)))
(advice-add '+lookup/definition :before #'+advice/xref-set-jump)
(advice-add '+lookup/references :before #'+advice/xref-set-jump)


(defvar +my/xref-blacklist nil
  "List of paths that should not enable xref-find-* or dumb-jump-go")

;;; Override
;; This function is transitively called by xref-find-{definitions,references,apropos}
(after! xref
  ;; This is required to make `xref-find-references' not give a prompt.
  ;; `xref-find-references' asks the identifier (which has no text property)
  ;; and then passes it to `lsp-mode', which requires the text property at
  ;; point to locate the references.
  ;; https://debbugs.gnu.org/cgi/bugreport.cgi?bug=29619
  (setq xref-prompt-for-identifier '(not xref-find-definitions
                                         xref-find-definitions-other-window
                                         xref-find-definitions-other-frame
                                         xref-find-references))

  (defun xref--show-xrefs (xrefs display-action &optional always-show-list)
    ;; PATCH
    (lsp-ui-peek--with-evil-jumps (evil-set-jump))

    ;; PATCH Jump to the first candidate
    (if (not (cdr xrefs))
        (xref--pop-to-location (car xrefs) display-action)
      (funcall xref-show-xrefs-function xrefs
               `((window . ,(selected-window))))
      ))

  (defun +my*ivy-xref-show-xrefs (xrefs alist)
    (let ((xref-pos (point))
          (xref-buffer (current-buffer))
          success)
      (ivy-read "xref: " (ivy-xref-make-collection xrefs)
                :require-match t
                :unwind (lambda ()
                          (unless success
                            (switch-to-buffer xref-buffer)
                            (goto-char xref-pos)
                            (recenter)))
                :action (lambda (candidate)
                          (setq success (eq 'ivy-done this-command))
                          (xref--show-location (cdr candidate) 'quit)))))
  (advice-add #'ivy-xref-show-xrefs :override #'+my*ivy-xref-show-xrefs)
  )

(after! ivy-xref
  ;; (defun ivy-xref-show-xrefs (xrefs alist)
  ;;   (minibuffer-with-setup-hook #'hydra-ivy/body
  ;;      (minibuffer-with-setup-hook #'ivy-toggle-calling
  ;;        (ivy-read "xref: " (ivy-xref-make-collection xrefs)
  ;;                  :require-match t
  ;;                  :action #'(lambda (candidate)
  ;;                              (xref--show-location (cdr candidate) 'quit))))))
  ;; (push '(xref-find-references) ivy-display-functions-alist)
  (push '(ivy-xref-show-xrefs . nil) ivy-sort-functions-alist)
  )

(def-package! treemacs
  :commands (treemacs treemacs-toggle)
  :config
  (setq treemacs-follow-after-init t)
  (treemacs-follow-mode +1)
  )

(def-package! treemacs-evil)

(def-package! treemacs-projectile
  :commands (treemacs-projectile treemacs-projectile-toggle))

(let ((profile "~/.config/doom/profile.el"))
  (when (file-exists-p profile)
    (load-file profile)))