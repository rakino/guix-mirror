;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2013-2017, 2020-2021, 2023-2024 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2022 Simon Tournier <zimon.toutoune@gmail.com>
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

(define-module (guix cache)
  #:autoload   (guix build syscalls) (lock-file unlock-file)
  #:use-module (srfi srfi-19)
  #:use-module (srfi srfi-26)
  #:use-module (ice-9 match)
  #:use-module ((ice-9 textual-ports) #:select (get-string-all))
  #:export (obsolete?
            delete-file*
            file-expiration-time
            remove-expired-cache-entries
            maybe-remove-expired-cache-entries))

;;; Commentary:
;;;
;;; This module provides tools to manage a simple on-disk cache consisting of
;;; individual files.
;;;
;;; Code:

(define (obsolete? date now ttl)
  "Return #t if DATE is obsolete compared to NOW + TTL seconds."
  (time>? (subtract-duration now (make-time time-duration 0 ttl))
          (make-time time-monotonic 0 date)))

(define (delete-file* file)
  "Like 'delete-file', but does not raise an error when FILE does not exist."
  (catch 'system-error
    (lambda ()
      (delete-file file))
    (lambda args
      (unless (= ENOENT (system-error-errno args))
        (apply throw args)))))

(define* (file-expiration-time ttl #:optional (timestamp stat:atime))
  "Return a procedure that, when passed a file, returns its \"expiration
time\" computed as its timestamp + TTL seconds.  Call TIMESTAMP to obtain the
relevant timestamp from the result of 'stat'."
  (lambda (file)
    (match (false-if-exception (lstat file))
      (#f 0)                       ;FILE may have been deleted in the meantime
      (st (+ (timestamp st) ttl)))))

(define* (remove-expired-cache-entries entries
                                       #:key
                                       (now (current-time time-monotonic))
                                       (entry-expiration
                                        (file-expiration-time 3600))
                                       (delete-entry delete-file*))
  "Given ENTRIES, a list of file names, remove those whose expiration time,
as returned by ENTRY-EXPIRATION, has passed.  Use DELETE-ENTRY to delete
them."
  (for-each (lambda (entry)
              (when (<= (entry-expiration entry) (time-second now))
                (delete-entry entry)))
            entries))

(define* (maybe-remove-expired-cache-entries cache
                                             cache-entries
                                             #:key
                                             (entry-expiration
                                              (file-expiration-time 3600))
                                             (delete-entry delete-file*)
                                             (cleanup-period (* 24 3600)))
  "Remove expired narinfo entries from the cache if deemed necessary.  Call
CACHE-ENTRIES with CACHE to retrieve the list of cache entries.

ENTRY-EXPIRATION must be a procedure that, when passed an entry, returns the
expiration time of that entry in seconds since the Epoch.  DELETE-ENTRY is a
procedure that removes the entry passed as an argument.  Finally,
CLEANUP-PERIOD denotes the minimum time between two cache cleanups."
  (define now
    (current-time time-monotonic))

  (define expiry-file
    (string-append cache "/last-expiry-cleanup"))

  (define expiry-port
    ;; Get exclusive access to EXPIRY-FILE to avoid "cleanup storms" where
    ;; several processes would concurrently decide that time has come to clean
    ;; up the same cache.  'lock-file' might throw to 'system-error' or to
    ;; 'flock-error'; in either case, assume that we lost the race.
    (false-if-exception
     (lock-file expiry-file "a+0" #:wait? #f)))

  (define last-expiry-date
    (if expiry-port
        (or (string->number (get-string-all expiry-port))
            0)
        +inf.0))

  (when (obsolete? last-expiry-date now cleanup-period)
    (remove-expired-cache-entries (cache-entries cache)
                                  #:now now
                                  #:entry-expiration entry-expiration
                                  #:delete-entry delete-entry)
    (catch 'system-error
      (lambda ()
        (seek expiry-port 0 SEEK_SET)
        (truncate-file expiry-port 0)
        (write (time-second now) expiry-port)
        (unlock-file expiry-port))
      (lambda args
        ;; ENOENT means CACHE does not exist.
        (unless (= ENOENT (system-error-errno args))
          (apply throw args))))))

;;; cache.scm ends here
