;;; pwdgen.el --- Generate secure passwords without leaving Emacs -*- lexical-binding: t -*-

;; Author: Will Dey
;; Maintainer: Will Dey
;; Version: 1.0.0
;; Package-Requires: ()
;; Homepage: https://github.com/wi11dey/pwdgen.el
;; Keywords: tools, lisp, unix
;; Created: 10 January 2020

;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;; Generate README:
;;; Commentary:
;; Library for generating secure passwords from within Emacs.  Simple and intuitive; see [[Example]]

;; Linux, BSD, macOS, and other Unix-like systems only until I can find a way to fetch sufficiently random characters from Emacs for Windows (see [[Built-in pseudo-random number generator]]).

;;;; Usage
;; #+begin_src emacs-lisp
;; (pwdgen length with-chars &optional without-chars)
;; #+end_src
;; Call the `pwdgen' function from Lisp or the [[https://masteringemacs.org/article/complete-guide-mastering-eshell][Eshell]] to generate a secure password of `length' characters using the characters `with-chars', optionally excluding the characters in `without-chars'.  You can use regex character alternative notation for `with-chars' and `without-chars'.  Like so:

;;;;; Example
;; #+begin_src emacs-lisp
;; (pwdgen 32 "A-Za-z0-9")    ; Generate a 32-character password with only alphanumeric characters
;; ⇒ "6sud2B3eRTcGWnS8ttOBJaS0YfJyKVWm"
;; (pwdgen 16 "!-~" "A-Za-z") ; Generate a 16-character password using all printable ASCII characters EXCEPT letters
;; ⇒ "!,*#':3_$~8;'0|]"
;; #+end_src

;; See the documentation of the `pwdgen' function for more details.

;;;;; Eshell
;; If you use the [[https://masteringemacs.org/article/complete-guide-mastering-eshell][amazing]] [[https://www.gnu.org/software/emacs/manual/html_mono/eshell.html][Eshell]], `pwdgen' acts like other command-line password generators:
;; #+begin_src sh
;; ~ $ pwdgen 32 A-Za-z0-9
;; MYHdBLc9P7l3GPRPMNnj2IoQJVB5T3k9
;; ~ $ pwdgen 16 "!-~" A-Za-z
;; /1&]-%(/#"79@#[>
;; #+end_src

;;;; Roadmap
;;;;; Front-end library
;; Front-end interactive commands can be written that use `pwdgen' as a secure backend.  Right now, this is left up to users to match their personal taste.  However, an interface could be written in the future to provide a uniform interface to `pwdgen'.
;;;;; Built-in pseudo-random number generator
;; Write an Elisp-only implementation of the [[https://en.wikipedia.org/wiki/Mersenne_twister][Mersenne Twister]] to generate sufficiently random numbers in the absence of /dev/urandom.  This would allow password generation on Emacs for Windows since Windows doesn’t have an analogue for Unix’s /dev/urandom.

;;; Code:

(defun pwdgen--delete-regexp (begin end regexp)
  "Delete everything between BEGIN and END in the current buffer matching REGEXP."
  (save-match-data
    (goto-char begin)
    (while (re-search-forward regexp end :noerror)
      (replace-match ""
		     :fixedcase
		     :literal))))

(defconst pwdgen--rng-chunk-size 100
  "How many bytes to read from the random device file at a time.")

;;;###autoload
(defun pwdgen (length with-chars &optional without-chars)
  "Generate securely random password of LENGTH characters.
Allowed characters are specified by WITH-CHARS, which follows
character alternative format (see Info node `(elisp)Regexp
Special').

All rules of character alternatives apply, so ranges of
characters can be written like \"A-Za-z0-9\".
To match a literal ], it should be the first character.
To match a -, it should be either the first or last character, or
  the upper bound of a range.
To match a ^, it should be anywhere but the first character.  Do
  not use ^ to exclude characters; instead, use WITHOUT-CHARS
  described below:

If WITHOUT-CHARS is non-nil, it is a character alternative in the
same format as WITH-CHARS but lists characters that should be
excluded from the password.

The generated password will contain the characters WITH-CHARS
minus WITHOUT-CHARS.  This function will continue to read from the
system's random source until enough acceptable characters are
gathered.

As an example, the character alternative \"!-~\" will match all
printable ASCII characters when used as the value of WITH-CHARS."
  (with-temp-buffer
    (let ((chunk-start (point-min)))
      (while (< (buffer-size) length)
	(call-process-shell-command (format "head -c %d /dev/urandom"
					    pwdgen--rng-chunk-size)
				    nil
				    t)
	(pwdgen--delete-regexp chunk-start nil (format "[^%s]"
						       with-chars))
	(when without-chars
	  (pwdgen--delete-regexp chunk-start nil (if (equal without-chars "^") ; Stop possible infinite loop as [^] would match all characters.
						     "\\^"
						   (format "[%s]"
							   without-chars))))
	(goto-char (setq chunk-start (point-max)))))
    (buffer-substring-no-properties 1 (1+ length))))

(provide 'pwdgen)

;;; pwdgen.el ends here
