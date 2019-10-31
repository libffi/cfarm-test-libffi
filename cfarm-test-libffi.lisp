;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CFARM-TEST-LIBFFI; Base: 10 -*-
;;;
;;; Copyright (C) 2019  Anthony Green <green@moxielogic.com>

;;; cfarm-test-libffi is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 3, or
;;; (at your option) any later version.
;;;
;;; cfarm-test-libffi is distributed in the hope that it will be
;;; useful, but WITHOUT ANY WARRANTY; without even the implied
;;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;;; See the GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with cfarm-test-libffi; see the file COPYING3.  If not see
;;; <http://www.gnu.org/licenses/>.

;; Top level for cfarm-test-libffi

(in-package :cfarm-test-libffi)

;; Our server....

(defvar *hunchentoot-server* nil)

(defparameter +root-path+ (asdf:component-pathname (asdf:find-system "cfarm-test-libffi")))

(defun read-file-into-string (filename)
  "Read FILENAME into a string and return that.
   If filename is not an absolute path, find it relative to the
   rlgl-server system (provided by asdf)."
  (let ((absolute-filename (if (cl-fad:pathname-absolute-p filename)
			       filename
			       (merge-pathnames +root-path+ filename))))
    (with-open-file (stream absolute-filename :external-format :UTF-8)
      (let ((contents (make-string (file-length stream))))
	(read-sequence contents stream)
	contents))))

(defvar *config*
  (if (fad:file-exists-p "/etc/cfarm-test-libffi/config.ini")
      (cl-toml:parse
       (read-file-into-string "/etc/cfarm-test-libffi/config.ini"))
      (make-hash-table)))

;; Start the web app.

(defun start-webapp (&rest interactive)
  "Start the web application and have the main thread sleep forever,
  unless INTERACTIVE is non-nil."
  ;;; Create an empty file.
  (with-open-file (stream "/tmp/known_hosts" :direction :output))
  (format t "** Starting hunchentoot on port 8080~%")
  (setq *hunchentoot-server* (hunchentoot:start 
			      (make-instance 'hunchentoot:easy-acceptor 
					     :port 8080)))
  (if (not interactive)
      (loop
	 (sleep 3000))))

(defun stop-webapp ()
  "Stop the web application."
  (hunchentoot:stop *hunchentoot-server*))

(defvar *host-map* (make-hash-table :test 'equal))

(defvar *cfarm-hosts*
  '(("powerpc64le-unknown-linux-gnu" ("gcc112.fsffrance.org" . 22))))
  
(mapc (lambda (host)
	(setf (gethash (car host) *host-map*) (cdr host)))
      *cfarm-hosts*)

(defun get-config-value (key)
  (or (gethash key *config*)
      (error "config does not contain key '~A'" key)))

(defun run-cfarm-tests (host-triple commit)
  (setf (content-type*) "text/plan")
  (let ((host (gethash host-triple *host-map*)))
    (if host
	(if commit
	    (ssh:with-connection (conn (car (car host))
				       (ssh:key (get-config-value "ssh-username")
						(truename (get-config-value "ssh-private-key")))
				       "/tmp/known_hosts")
	      (ssh:upload-file conn
			       (merge-pathnames +root-path+ "cfarm-test-libffi.sh")
			       #p"cfarm-test-libffi.sh")
	      (setf (content-type*) "text/plain")
	      (let* ((stream (hunchentoot:send-headers))
		     (buffer (make-array 128 :element-type 'flex:octet))
		     (rstring
		       (with-output-to-string (rstring-stream)
			 (ssh:with-command (conn iostream (format nil "source ./cfarm-test-libffi.sh ~A" commit))
					   (loop for pos = (read-sequence buffer iostream)
						 until (zerop pos) 
						 do (progn
						      (format rstring-stream
							      "~A" (flexi-streams:octets-to-string buffer :external-format :utf-8 :end pos))
						      (write-sequence buffer stream :end pos)))
					   (format nil "Log file: https://~A/libffi.log" "cfarm-test-libffi-libffi.apps.home.labdroid.net")))))
		(with-input-from-string (in rstring)
		  (loop for line = (read-line in nil)
			while line do
			  (when (str:starts-with? "==LOGFILE== " line)
			    (let ((remote-filename (str:substring 12 nil line)))
			      (ssh:download-file conn #p"/tmp/DOWNLOAD" remote-filename)
			      (ssh:with-command (conn iostream (format nil "rm ~A" remote-filename)))))))))
	    (format nil "Missing commit hash"))
	(format nil "Unsupported host-triple ~A" host-triple))))

(EVAL-WHEN (:COMPILE-TOPLEVEL :LOAD-TOPLEVEL :EXECUTE)
  
  (hunchentoot:define-easy-handler (test :uri "/test") (host commit)
    (run-cfarm-tests host commit))
  
  (hunchentoot:define-easy-handler (status :uri "/health") ()
    (setf (hunchentoot:content-type*) "text/plain")
    (format nil "It's all good"))
 
  )

