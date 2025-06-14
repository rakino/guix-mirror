;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2025 Maxim Cournoyer <maxim.cournoyer@gmail.com>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages go-apps)
  #:use-module (guix build-system go)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (gnu packages)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages golang-build)
  #:use-module (gnu packages golang-check)
  #:use-module (gnu packages golang-xyz))

(define-public godef
  (package
    (name "godef")
    (version "1.1.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/rogpeppe/godef")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0rhhg73kzai6qzhw31yxw3nhpsijn849qai2v9am955svmnckvf4"))
       (modules '((guix build utils)))
       (snippet '(delete-file-recursively "vendor"))))
    (build-system go-build-system)
    (arguments
     (list
      #:import-path "github.com/rogpeppe/godef"
      ;; The TestGoDef/Modules test fails, because of the lack of Go modules
      ;; support.
      #:test-flags #~(list "-skip" "TestGoDef/GOPATH|TestGoDef/Modules")))
    (inputs
     (list go-golang-org-x-tools
           go-ninefans-net-go))
    (home-page "https://github.com/rogpeppe/godef")
    (synopsis "Print where symbols are defined in Go source code")
    (description "The @command{godef} command prints the source location of
definitions in Go programs.")
    (license license:bsd-3)))

(define-public gore
  (package
    (name "gore")
    (version "0.6.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/x-motemen/gore")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0d8ayzni43j1y02g9j2sx1rhml8j1ikbbzmcki2lyi4j0ix5ys7f"))))
    (build-system go-build-system)
    (arguments
     (list
      #:go go-1.23                      ;required by motemen-go-quickfix
      #:import-path "github.com/x-motemen/gore"
      #:install-source? #f
      #:test-flags
      ;; Gore is configured for building modules with Go module
      ;; support, which fails in the build environment for the tests
      ;; making use of that.  Skip them.
      #~(list "-skip" (string-join
                       (list "TestAction_ArgumentRequired"
                             "TestAction_Clear"
                             "TestAction_CommandNotFound"
                             "TestAction_Help"
                             "TestAction_Import"
                             "TestAction_Quit"
                             "TestSessionEval_AutoImport"
                             "TestSessionEval_CompileError"
                             "TestSessionEval_Const"
                             "TestSessionEval_Copy"
                             "TestSessionEval_Declarations"
                             "TestSessionEval_Func"
                             "TestSessionEval_Gomod"
                             "TestSessionEval_Gomod_CompleteImport"
                             "TestSessionEval_Gomod_DeepDir"
                             "TestSessionEval_Gomod_Outside"
                             "TestSessionEval_MultipleValues"
                             "TestSessionEval_NotUsed"
                             "TestSessionEval_QuickFix_evaluated_but_not_used"
                             "TestSessionEval_QuickFix_no_new_variables"
                             "TestSessionEval_QuickFix_used_as_value"
                             "TestSessionEval_Struct"
                             "TestSessionEval_TokenError"
                             "TestSessionEval_import"
                             "TestSession_IncludePackage"
                             "TestSession_completeWord")
                       "|"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch-commands
            (lambda* (#:key inputs #:allow-other-keys)
              (with-directory-excursion "src/github.com/x-motemen/gore"
                (substitute* "gopls.go"
                  (("\"gopls\"")
                   (format #f "~s" (search-input-file inputs "bin/gopls")))))))
          (replace 'install
            (lambda _
              (with-directory-excursion "src/github.com/x-motemen/gore"
                (invoke "make" "install")))))))
    (native-inputs
     (list go-github-com-motemen-go-quickfix
           go-github-com-peterh-liner
           go-github-com-stretchr-testify
           go-go-lsp-dev-jsonrpc2
           go-go-lsp-dev-protocol
           go-golang-org-x-text
           go-golang-org-x-tools))
    (inputs
     (list gopls))
    (home-page "https://github.com/x-motemen/gore")
    (synopsis "Go REPL with line editing and completion capabilities")
    (description
     "Gore is a Go @acronym{REPL, read-eval-print loop} that offers line
editing and auto-completion.  Some of its features include:
@itemize
@item Line editing with history
@item Multi-line input
@item Package importing with completion
@item Evaluates any expressions, statements and function declarations
@item No ``evaluated but not used'' errors
@item Code completion
@item Showing documents
@item Auto-importing (gore -autoimport)
@end itemize")
    (license license:expat)))
