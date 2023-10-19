;;; -*- Gerbil -*-
;;; Simple web server, based on vyzo's example in gerbil/src/tutorial/httpd/simpled.ss
(import
  :std/getopt
  :std/iter
  :std/misc/path
  :std/misc/ports
  :std/net/httpd
  :std/net/httpd
  :std/net/address
  :std/text/json
  :std/source
  :std/sugar
  :std/xml)
(export main)

(def data-root (make-parameter #f))

(def (run address data-dir)
  (parameterize ((data-root data-dir))
    (let (httpd (start-http-server! address mux: (make-default-http-mux default-handler)))
      (http-register-handler httpd "/" root-handler)
      (http-register-handler httpd "/gerbil.png" gerbil.png-handler)
      (http-register-handler httpd "/echo" echo-handler)
      (http-register-handler httpd "/main.ss" file-handler)
      (http-register-handler httpd "/headers" headers-handler)
      (http-register-handler httpd "/self" self-handler)
      (thread-join! httpd))))

;; /
(def (root-handler req res)
  (http-response-write res 200 '(("Content-Type" . "text/html"))
    (sxml->xhtml-string
     `(html
       (head
        (meta (@ (http-equiv "Content-Type") (content "text/html; charset=utf-8")))
        (title "Heroku Example Server in Gerbil Scheme")
        (link (@ (rel "icon") (href "/gerbil.png") (type "image/png")))
       (body
        (h1 "Hello, " ,(inet-address->string (http-request-client req)))
        (p "Welcome to this "
           (a (@ (href "https://heroku.com")) "Heroku")
           " Example Server written in "
           (a (@ (href "https://cons.io")) "Gerbil Scheme") "! "
           "See the github repositories "
           (a (@ (href "https://github.com/heroku-gerbil/heroku-example-gerbil"))
              "for this app")
           " and "
           (a (@ (href "https://github.com/heroku-gerbil/heroku-buildpack-gerbil"))
              "for the Gerbil buildpack") ".")
        (img (@ (src "/gerbil.png") (alt "Gerbil Logo")))
        (p "This app is serving " (a (@ (href "/main.ss")) "its own source code") ".")))))))

;; /gerbil.png -- burnt into the executable at compile-time
(def (gerbil.png-handler req res)
  (http-response-write res 200 '(("Content-Type" . "image/png"))
    (this-source-content "gerbil.png")))

(def (content-type-from-extension path)
  (case (path-extension path)
    ((".html" ".htm") "text/html")
    ((".txt" ".text" ".md" ".ss") "text/plain")
    ((".png") "image/png")
    ((".jpg" ".jpeg") "image/jpeg")
    (else #f)))

;; /main.ss -- loaded from the filesystem at runtime
(def (file-handler req res)
  (let* ((req-path (http-request-path req))
         (file-path (string-append (data-root) req-path))
         (content-type (content-type-from-extension req-path)))
    (writeln [file-handler: req-path file-path content-type])
    (if (and content-type (file-exists? file-path))
      (http-response-file res `(("Content-Type" . ,content-type)) file-path)
      (http-response-write-condition res Not-Found))))

;; /echo
(def (echo-handler req res)
  (let* ((content-type
          (assget "Content-Type" (http-request-headers req)))
         (headers
          (if content-type
            [["Content-Type" . content-type]]
            [])))
    (http-response-write res 200 headers
      (http-request-body req))))

;; /headers[?json]
(def (headers-handler req res)
  (let (headers (http-request-headers req))
    (if (equal? (http-request-params req) "json")
      (write-json-headers res headers)
      (write-text-headers res headers))))

(def (write-json-headers res headers)
  (let (content
        (json-object->string
         (list->hash-table headers)))
    (http-response-write res 200 '(("Content-Type" . "application/json"))
      content)))

(def (write-text-headers res headers)
  (http-response-begin res 200 '(("Content-Type" . "text/plain")))
  (for ([key . val] headers)
    (http-response-chunk res (string-append key ": " val "\n")))
  (http-response-end res))

;; /self
;; own program representation
(def (self-handler req res)
  (http-response-file res '(("Content-Type" . "text/plain")) "server.ss"))

;; default
(def (default-handler req res)
  (http-response-write res 404 '(("Content-Type" . "text/plain"))
    "The gerbils couldn't find the page you're looking for.\n"))

(def (main . args)
  (call-with-getopt server-main args
    program: "server"
    help: "A example heroku server in Gerbil Scheme"
    (option 'address "-a" "--address"
      help: "server address"
      default: #f)
    (option 'data-dir "-d" "--data-dir"
      help: "data directory"
      default: #f)))

(def (server-main opt)
  (run (or (hash-ref opt 'address)
           (string-append "0.0.0.0:" (getenv "PORT" "8080")))
       (or (hash-ref opt 'data-dir)
           (getenv "HOME" "/app"))))
