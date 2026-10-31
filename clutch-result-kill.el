;;; clutch-result-kill.el --- Copy the cell at point with M-w -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Lucius Chen
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is part of clutch.

;;; Commentary:

;; `M-w' in a result or record buffer saves the value of the cell at
;; point, as the grid shows it with JSON pretty printed; a prefix
;; argument saves the value as the database returned it.  With an
;; active region it saves the region.  Kept apart from
;; `clutch-result.el' in this fork so the binding survives changes
;; there.

;;; Code:

(require 'clutch-result)
(require 'json)
(require 'subr-x)

(defun clutch-result--kill-json-text (val col-def)
  "Return VAL pretty printed when it is JSON in COL-DEF, else nil."
  (when (or (eq (plist-get col-def :type-category) 'json)
            (clutch--json-view-string-p val))
    (condition-case nil
        (with-temp-buffer
          (insert (clutch--json-value-to-string val))
          (json-pretty-print-buffer)
          (buffer-string))
      (error nil))))

(defun clutch-result--kill-display-text (val col-def)
  "Return VAL in COL-DEF as the grid displays it, JSON pretty printed."
  (or (when-let* ((custom (clutch--cell-custom-display val col-def)))
        (substring-no-properties custom))
      (clutch-result--kill-json-text val col-def)
      (clutch--value-placeholder val col-def)
      (clutch--cell-text val col-def)))

(defun clutch-result--kill-text (val col-def native)
  "Return the text to save for VAL in COL-DEF, or nil when VAL is NULL.
NATIVE non-nil means the value as the database returned it."
  (cond
   ((null val) nil)
   ((and native (clutch--cell-placeholder-value val)) "")
   ((clutch--cell-placeholder-value val))
   ((and native (clutch-db-value-preview-p val))
    (user-error "Value is incomplete; open it with `v' for the loaded part"))
   (native (clutch--format-value val))
   (t (clutch-result--kill-display-text val col-def))))

;;;###autoload
(defun clutch-result-kill-ring-save (&optional native)
  "Save the cell at point to the kill ring, or the active region.
The cell is saved as displayed, with JSON pretty printed.  With prefix
argument NATIVE, save the value as the database returned it.  A NULL
cell saves an empty string.  An active region is saved instead of the cell."
  (interactive "P")
  (if (use-region-p)
      (call-interactively #'kill-ring-save)
    (pcase-let ((`(,_ridx ,cidx ,val)
                 (or (clutch--cell-at-point) (user-error "No cell at point"))))
      (let* ((defs (if (derived-mode-p 'clutch-record-mode)
                       (and (buffer-live-p clutch-record--result-buffer)
                            (buffer-local-value 'clutch--result-column-defs
                                                clutch-record--result-buffer))
                     clutch--result-column-defs))
             (text (clutch-result--kill-text val (nth cidx defs) native)))
        (kill-new (or text ""))
        (message (cond ((null val) "NULL value: copied empty string")
                       ((string-empty-p text) "Copied empty value")
                       (t "Copied %s"))
                 (truncate-string-to-width
                  (replace-regexp-in-string "[\n\t ]+" " " (or text ""))
                  40 nil nil "…"))))))

(define-key clutch-result-mode-map (kbd "M-w") #'clutch-result-kill-ring-save)
(define-key clutch-record-mode-map (kbd "M-w") #'clutch-result-kill-ring-save)

(provide 'clutch-result-kill)

;;; clutch-result-kill.el ends here
