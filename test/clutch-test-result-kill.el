;;; clutch-test-result-kill.el --- M-w cell copy tests for clutch -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests for `clutch-result-kill-ring-save'.

;;; Code:

(eval-and-compile
  (require 'clutch-test-common)
  (require 'clutch-result-kill))

(defun clutch-test--kill-cell (row col &optional native)
  "Return the text `clutch-result-kill-ring-save' saves at ROW, COL.
NATIVE is its prefix argument."
  (clutch-test--select-cells (list row col))
  (let ((kill-ring nil))
    (cl-letf (((symbol-function 'message) #'ignore))
      (clutch-result-kill-ring-save native))
    (current-kill 0)))

(ert-deftest clutch-test-kill-cell-text-and-number-format ()
  "Display mode saves the shaped text, a prefix argument the stored value."
  (let ((clutch-number-format "#,##0.00"))
    (clutch-test--with-result-state
        (:columns '("id" "n" "s")
         :column-defs '((:name "id") (:name "n" :type-category numeric)
                        (:name "s"))
         :rows (list (list 1 1234.5 (make-string 300 ?x)))
         :render t)
      (should (equal (clutch-test--kill-cell 0 1) "1,234.50"))
      (should (equal (clutch-test--kill-cell 0 1 '(4)) "1234.5"))
      (should (equal (clutch-test--kill-cell 0 2) (make-string 300 ?x))))))

(ert-deftest clutch-test-kill-cell-json-pretty-prints-unless-native ()
  "JSON saves pretty printed; a prefix argument saves the original text."
  (clutch-test--with-result-state
      (:columns '("id" "j") :rows (list (list 1 "{\"a\":1,\"b\":[2]}")) :render t)
    (should (string-match-p "\n" (clutch-test--kill-cell 0 1)))
    (should (equal (json-parse-string (clutch-test--kill-cell 0 1)
                                      :object-type 'alist)
                   '((a . 1) (b . [2]))))
    (should (equal (clutch-test--kill-cell 0 1 '(4)) "{\"a\":1,\"b\":[2]}"))))

(ert-deftest clutch-test-kill-cell-null-and-placeholders ()
  "NULL saves an empty string; a staged placeholder saves its marker."
  (clutch-test--with-result-state
      (:columns '("id" "v")
       :rows (list (list 1 nil) (list 2 clutch--cell-default-placeholder))
       :render t)
    (should (equal (clutch-test--kill-cell 0 1) ""))
    (should (equal (clutch-test--kill-cell 0 1 '(4)) ""))
    (should (equal (clutch-test--kill-cell 1 1) "<default>"))
    (should (equal (clutch-test--kill-cell 1 1 '(4)) ""))))

(ert-deftest clutch-test-kill-cell-custom-displayer-without-properties ()
  "A column displayer's text saves without text properties."
  (let ((clutch-column-displayers
         `(("t" . (("v" . ,(lambda (v) (propertize (format "<%s>" v) 'face 'bold))))))))
    (clutch-test--with-result-state
        (:columns '("id" "v") :rows (list (list 1 "a")) :render t)
      (setq-local clutch--result-source-table "t")
      (should (equal-including-properties (clutch-test--kill-cell 0 1) "<a>")))))

(ert-deftest clutch-test-kill-region-and-no-cell ()
  "An active region uses `kill-ring-save'; no cell is a user error."
  (clutch-test--with-result-state
      (:columns '("id" "v") :rows (list (list 1 "a")) :render t)
    (clutch-test--select-cells '(0 0) '(0 1))
    (let ((kill-ring nil))
      (clutch-result-kill-ring-save)
      (should (equal (current-kill 0)
                     (buffer-substring-no-properties (mark) (point))))))
  (with-temp-buffer
    (should-error (clutch-result-kill-ring-save) :type 'user-error)))

(ert-deftest clutch-test-kill-record-field-from-its-name ()
  "Point on a field's name saves that field's value."
  (clutch-test--with-result-state-buffer result-buf
      (:columns '("id" "name") :rows (list (list 1 "alice")) :render t)
    (with-temp-buffer
      (clutch-record-mode)
      (setq-local clutch-record--result-buffer result-buf
                  clutch-record--row-idx 0)
      (clutch-record--render)
      (goto-char (point-min))
      (search-forward "name")
      (let ((kill-ring nil))
        (cl-letf (((symbol-function 'message) #'ignore))
          (clutch-result-kill-ring-save))
        (should (equal (current-kill 0) "alice"))))))

(ert-deftest clutch-test-kill-binds-m-w-in-result-and-record-maps ()
  "M-w runs the command in both modes."
  (should (eq (lookup-key clutch-result-mode-map (kbd "M-w"))
              #'clutch-result-kill-ring-save))
  (should (eq (lookup-key clutch-record-mode-map (kbd "M-w"))
              #'clutch-result-kill-ring-save)))

(provide 'clutch-test-result-kill)

;;; clutch-test-result-kill.el ends here
