;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2018, 2019, 2022 Ricardo Wurmus <rekado@elephly.net>
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
;;; You should have received a copy of thye GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu services ldap)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages openldap)
  #:use-module (gnu services)
  #:use-module (gnu services configuration)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system shadow)
  #:use-module (guix gexp)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (ice-9 string-fun)
  #:export (directory-server-service-type
            directory-server-shepherd-service

            directory-server-instance-configuration
            slapd-configuration
            backend-userroot-configuration))

(define (uglify-field-name name)
  (let ((str (string-map (match-lambda
                           (#\- #\_)
                           (chr chr))
                         (symbol->string name))))
    (if (string-suffix? "?" str)
        (substring str 0 (1- (string-length str)))
        str)))
(define (serialize-field field-name val)
  (format #t "~a = ~a\n" (uglify-field-name field-name) val))
(define serialize-string serialize-field)
(define-maybe string)
(define (serialize-boolean field-name val)
  (serialize-field field-name (if val "True" "False")))
(define (serialize-number field-name val)
  (serialize-field field-name (number->string val)))


(define-configuration slapd-configuration
  (instance-name
   (string "localhost")
   "Sets the name of the instance.  You can refer to this value in other
parameters of this INF file using the \"{instance_name}\" variable.  Note that
this name cannot be changed after the installation!")
  (user
   (string "dirsrv")
   "Sets the user name the ns-slapd process will use after the service
started.")
  (group
   (string "dirsrv")
   "Sets the group name the ns-slapd process will use after the service
started.")
  (port
   (number 389)
   "Sets the TCP port the instance uses for LDAP connections.")
  (secure-port
   (number 636)
   "Sets the TCP port the instance uses for TLS-secured LDAP
connections (LDAPS).")
  (root-dn
   (string "cn=Directory Manager")
   "Sets the Distinquished Name (DN) of the administrator account for this
instance.")
  (root-password
   (string "{invalid}YOU-SHOULD-CHANGE-THIS")
   "Sets the password of the account specified in the \"root-dn\" parameter.
You can either set this parameter to a plain text password dscreate hashes
during the installation or to a \"{algorithm}hash\" string generated by the
pwdhash utility.  Note that setting a plain text password can be a security
risk if unprivileged users can read this INF file!")
  (self-sign-cert
   (boolean #t)
   "Sets whether the setup creates a self-signed certificate and enables TLS
encryption during the installation.  This is not suitable for production, but
it enables administrators to use TLS right after the installation.  You can
replace the self-signed certificate with a certificate issued by a certificate
authority.")
  (self-sign-cert-valid-months
   (number 24)
   "Set the number of months the issued self-signed certificate will be valid.")
  (backup-dir
   (string "/var/lib/dirsrv/slapd-{instance_name}/bak")
   "Set the backup directory of the instance.")
  (cert-dir
   (string "/etc/dirsrv/slapd-{instance_name}")
   "Sets the directory of the instance's Network Security Services (NSS)
database.")
  (config-dir
   (string "/etc/dirsrv/slapd-{instance_name}")
   "Sets the configuration directory of the instance.")
  (db-dir
   (string "/var/lib/dirsrv/slapd-{instance_name}/db")
   "Sets the database directory of the instance.")
  (initconfig-dir
   (string "/etc/dirsrv/registry")
   "Sets the directory of the operating system's rc configuration directory.")
  (ldif-dir
   (string "/var/lib/dirsrv/slapd-{instance_name}/ldif")
   "Sets the LDIF export and import directory of the instance.")
  (lock-dir
   (string "/var/lock/dirsrv/slapd-{instance_name}")
   "Sets the lock directory of the instance.")
  (log-dir
   (string "/var/log/dirsrv/slapd-{instance_name}")
   "Sets the log directory of the instance.")
  (run-dir
   (string "/run/dirsrv")
   "Sets PID directory of the instance.")
  (schema-dir
   (string "/etc/dirsrv/slapd-{instance_name}/schema")
   "Sets schema directory of the instance.")
  (tmp-dir
   (string "/tmp")
   "Sets the temporary directory of the instance."))

(define (serialize-slapd-configuration field-name val)
  #t)


(define-configuration backend-userroot-configuration
  (create-suffix-entry?
   (boolean #false)
   "Set this parameter to #true to create a generic root node entry for the
suffix in the database.")
  (require-index?
   (boolean #false)
   "Set this parameter to #true to refuse unindexed searches in this
database.")
  (sample-entries
   (string "no")
   "Set this parameter to \"yes\" to add latest version of sample entries to
this database.  Or, use \"001003006\" to use the 1.3.6 version sample entries.
Use this option, for example, to create a database for testing purposes.")
  (suffix
   maybe-string
   "Sets the root suffix stored in this database.  If you do not set the
suffix attribute the install process will not create the backend/suffix.  You
can also create multiple backends/suffixes by duplicating this section."))

(define (serialize-backend-userroot-configuration field-name val)
  #t)


(define-configuration directory-server-instance-configuration
  (package
    (file-like 389-ds-base)
    "The 389-ds-base package.")
  ;; General settings
  (config-version
   (number 2)
   "Sets the format version of the configuration file.  To use the INF file
with dscreate, this parameter must be 2.")
  (full-machine-name
   (string "localhost")
   "Sets the fully qualified hostname (FQDN) of this system.")
  (selinux
   (boolean #false)
   "Enables SELinux detection and integration during the installation of this
instance.  If set to #T, dscreate auto-detects whether SELinux is enabled.")
  (strict-host-checking
   (boolean #t)
   "Sets whether the server verifies the forward and reverse record set in the
\"full-machine-name\" parameter.  When installing this instance with GSSAPI
authentication behind a load balancer, set this parameter to #F.")
  (systemd
   (boolean #false)
   "Enables systemd platform features.  If set to #T, dscreate auto-detects
whether systemd is installed.")
  (slapd
   (slapd-configuration (slapd-configuration))
   "Configuration of slapd.")
  (backend-userroot
   (backend-userroot-configuration (backend-userroot-configuration))
   "Configuration of the userroot backend."))

(define (serialize-directory-server-instance-configuration x)
  (format #t "[general]\n")
  (serialize-configuration
   x
   (filter (lambda (field)
             (not (member (configuration-field-name field)
                          '(package slapd backend-userroot))))
           directory-server-instance-configuration-fields))
  ;; Do not start instance while running dscreate.  Do this later with
  ;; shepherd.
  (format #t "start = False\n")
  (format #t "\n[slapd]\n")
  (serialize-configuration
   (directory-server-instance-configuration-slapd x)
   slapd-configuration-fields)
  (format #t "\n[backend-userroot]\n")
  (serialize-configuration
   (directory-server-instance-configuration-backend-userroot x)
   backend-userroot-configuration-fields))

(define (directory-server-instance-config-file config)
  "Return an LDAP directory server instance configuration file."
  (let* ((slapd   (directory-server-instance-configuration-slapd config))
         (instance-name (slapd-configuration-instance-name slapd)))
    (plain-file
     (string-append "dirsrv-" instance-name ".inf")
     (with-output-to-string
       (lambda ()
         (serialize-directory-server-instance-configuration config))))))

(define (directory-server-shepherd-service config)
  "Return a shepherd service for an LDAP directory server with CONFIG."
  (let* ((389-ds-base (directory-server-instance-configuration-package config))
         (slapd       (directory-server-instance-configuration-slapd config))
         (instance-name
          (slapd-configuration-instance-name slapd)))
    (list (shepherd-service
           (documentation "Run an 389 directory server instance.")
           (provision (list (symbol-append 'directory-server-
                                           (string->symbol instance-name))))
           (requirement '(user-processes))
           (start #~(make-forkexec-constructor
                     (list #$(file-append 389-ds-base "/sbin/dsctl")
                           #$instance-name "start")
                     #:pid-file
                     (string-append
                      #$(slapd-configuration-run-dir slapd)
                      "/slapd-" #$instance-name ".pid")))
           (stop #~(make-kill-destructor))))))

(define (directory-server-accounts config)
  (let* ((slapd (directory-server-instance-configuration-slapd config))
         (user (slapd-configuration-user slapd))
         (group (slapd-configuration-group slapd)))
    (list (user-group
           (name group)
           (system? #true))
          (user-account
           (name user)
           (group group)
           (system? #true)
           (comment "System user for the 389 directory server")
           (home-directory "/var/empty")
           (shell (file-append shadow "/sbin/nologin"))))))

(define (directory-server-activation config)
  (let* ((389-ds-base (directory-server-instance-configuration-package config))
         (config-file (directory-server-instance-config-file config))
         (slapd (directory-server-instance-configuration-slapd config))
         (instance-name (slapd-configuration-instance-name slapd))
         (user (slapd-configuration-user slapd))
         (group (slapd-configuration-group slapd))
         (instantiate (lambda (proc)
                        (string-replace-substring
                         (proc slapd) "{instance_name}" instance-name)))
         (config-dir (instantiate slapd-configuration-config-dir))
         (all-dirs (delete-duplicates
                    (map (compose dirname instantiate)
                         (list slapd-configuration-backup-dir
                               slapd-configuration-cert-dir
                               slapd-configuration-db-dir
                               slapd-configuration-ldif-dir
                               slapd-configuration-lock-dir
                               slapd-configuration-log-dir
                               slapd-configuration-run-dir
                               slapd-configuration-schema-dir)))))
    ;; 389-ds-base doesn't let us update an instance configuration, so bail
    ;; out when the configuration directory already exists.
    #~(begin
        (use-modules (ice-9 match)
                     (guix build utils))
        (if (file-exists? #$config-dir)
            (format #t
                    "directory-server: Instance configuration for `~a' already exists.  Skipping.\n"
                    #$instance-name)
            (let ((owner (getpwnam #$user)))
              (for-each (lambda (dir)
                          (mkdir-p dir)
                          (chown dir (passwd:uid owner) (passwd:gid owner)))
                        (sort '#$all-dirs string<=))
              (system* #$(file-append 389-ds-base "/sbin/dscreate")
                       "from-file" #$config-file))))))

(define directory-server-service-type
  (service-type (name 'directory-server)
                (extensions
                 (list (service-extension shepherd-root-service-type
                                          directory-server-shepherd-service)
                       (service-extension activation-service-type
                                          directory-server-activation)
                       (service-extension account-service-type
                                          directory-server-accounts)))
                (default-value (directory-server-instance-configuration))
                (description
                 "Run a directory server instance.")))

(define (generate-directory-server-documentation)
  (generate-documentation
    `((directory-server-instance-configuration
       ,directory-server-instance-configuration-fields
       (slapd slapd-configuration)
       (backend-userroot backend-userroot-configuration))
      (slapd-configuration ,slapd-configuration-fields)
      (backend-userroot-configuration
       ,backend-userroot-configuration-fields))
    'directory-server-instance-configuration))
