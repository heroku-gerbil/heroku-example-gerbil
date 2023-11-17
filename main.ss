;; -*- Gerbil -*-
;;; Simple web server, based on vyzo's example in gerbil/src/tutorial/httpd/simpled.ss
(import
  :gerbil/gambit
  :std/contract
  :std/db/dbi
  :std/db/postgresql
  :std/getopt
  :std/interface
  :std/iter
  :std/misc/path
  :std/misc/ports
  :std/misc/string
  :std/net/httpd
  :std/net/address
  :std/net/ssl
  :std/net/uri
  :std/pregexp
  :std/text/json
  :std/source
  :std/sugar
  :std/xml
  :std/xml/sxml-to-xml
  :std/text/utf8)
(export main)

(def data-root (make-parameter #f))
(def server-url (make-parameter "/"))
(def database-connection (make-parameter #f))

;; NB: The SXML syntax is a bit awkward, but it's the de-facto "standard" in Scheme.
;; TODO: port Racket's scribble-html to Gerbil and use it instead.
;; /
(def (root-handler req res)
  (http-response-write
   res 200 '(("Content-Type" . "text/html"))
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
        ,(shorten-form)
        (p "This app is serving " (a (@ (href "/main.ss")) "its own source code") ".")))))))

;; /gerbil.png -- Example for serving files found in the filesystem at compile-time
;; In this case, the file is burnt into the executable at compile-time, as opposed to
;; installed somewhere to be available at runtime. Compare to the file-handler below.
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

;; /main.ss -- Example for serving files found in the filesystem at runtime
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

(def url-server-rx
  (pregexp "^([^/]+://[^/]*)(/|$)"))

(def (url-server url)
  (match (pregexp-match url-server-rx url)
    ([_ server _] server)
    (else #f)))

;; Shorten
(def (shorten-handler req res)
  (def params (with-catch false (cut form-url-decode (utf8->string (http-request-body req)))))
  (def url (assget "url" params))
  (http-request-url req)
  (http-response-write
   res 200 '(("Content-Type" . "text/html"))
   (sxml->xhtml-string
    `(html
      (head (title "Demo URL Shortener"))
      (body
       (h1 "Demo URL Shortener")
       ,(cond
         ;;((not url-encoded) '())
         ((not url)
          `(p "No URL was provided."))
         (else
          (let (short-url (as-string (server-url) (make-short-url url)))
            `((p "You asked to shorten the url: " (code (a (@ (href ,url)) ,url)))
              (p "Here is a short url for it: " (code (a (@ (href ,short-url)) ,short-url)))))))
       (br)
       ,(shorten-form))))))

(def (shorten-form)
  '(form (@ (action "/shorten") (method "post"))
     (p "As a simple demo for using a database, you can create persistent short URLs.")
     (p (label "Full URL: " (input (@ (name "url")))))
     (p (input (@ (type "submit") (value "Shorten!"))))))

(def short-urls (hash))
(def short-urls-mutex (make-mutex "shorten"))

#|
;; Version without a database. TODO: use an in-memory cache?
(def (make-short-url url)
  (with-lock short-urls-mutex
    (lambda ()
      (def name (new-short-name))
      (hash-put! short-urls name url)
      name)))
(def (unshorten-url short)
  (hash-get short-urls short))
|#

(def short-url-chars
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
(def (random-url-char)
  (string-ref short-url-chars (random-integer 64)))

(def (new-short-name)
  ;; Start with two-character strings: reserve one-character paths for future uses.
  (let (s (as-string (random-url-char) (random-url-char)))
    (while (hash-key? short-urls s)
      (set! s (as-string s (random-url-char))))
    s))

(def (make-short-url url)
  (let loop ((short (as-string (random-url-char) (random-url-char))))
    (def (retry) (loop (as-string short (random-url-char))))
    (if (hash-key? short-urls short)
      (retry)
      (try (sql-eval (database-connection)
                     "INSERT INTO shorten_url (short, long) VALUES ($1, $2)" short url)
           (hash-put! short-urls short url)
           short
           (catch (e)
             (display-exception e)
             (retry))))))

(def (unshorten-url short)
  (or (hash-get short-urls short)
      (try (match (sql-eval-query (database-connection)
                                  "SELECT long FROM shorten WHERE short = $1" short)
             ([(vector long)] long)
             (else #f))
           (catch (e) (display-exception e) #f))))

;; Parse the DATABASE_URL from heroku into a list of server database user pass
;; : String -> (Tuple String String String String)
(def (parse-heroku-database-url url)
  (match (pregexp-match "^postgres://(([^:/]+)(:([^/@]*))?@)?([^@:/]+)(:([0-9]+))?/(.+)$" url)
    ([_ userpass user xpass pass host xport port database]
     [host (and port (string->number port)) database (and userpass user) (and xpass pass)])
    (else (error "Invalid database url" url))))

(def (pgsql-schema)
  "CREATE TABLE IF NOT EXISTS shorten_url (
     short varchar(100) NOT NULL,
     long varchar(2048) NOT NULL,
     PRIMARY KEY(short));")

;; default: handle unshorten, or else 404
(def (default-handler req res)
  (def path (http-request-path req))
  (cond
   ;; Unshorten URL
   ((unshorten-url (string-trim-prefix "/" path))
    => (lambda (url)
         (http-response-write
          res 307 `(("Content-Type" . "text/html")
                    ("Location" . ,url))
          (sxml->xhtml-string `(html (body "Moved to: " (a (@ (href ,url)) ,url)))))))
   ;; Not found
   (else
    (http-response-write res 404 '(("Content-Type" . "text/plain"))
                         "The gerbils couldn't find the page you're looking for.\n"))))

(def handlers
  [["/" root-handler]
   ["/gerbil.png" gerbil.png-handler]
   ["/echo" echo-handler]
   ["/shorten" shorten-handler]
   ["/main.ss" file-handler]
   ["/headers" headers-handler]
   ["/self" self-handler]])

(def (reserve-handler-short-names)
  (for-each
    (match <> ([path . _]
               (let (taken (string-trim-prefix "/" path))
                 (hash-put! short-urls taken taken))))
    handlers))

(def (run address data-dir database-url server-url/)
  (reserve-handler-short-names)
  (parameterize ((data-root data-dir)
                 (server-url server-url/))
    (with ([host port database user passwd] (parse-heroku-database-url database-url))
      (def connection (sql-connect postgresql-connect
                                   host: host port: 5432 user: user db: database passwd: passwd
                                   ssl?: (if (equal? host "localhost") 'try #t)
                                   ssl-context: (insecure-client-ssl-context))) ;; default
      (database-connection connection)
      (sql-eval connection (pgsql-schema))
      (def httpd (start-http-server! address mux: (make-default-http-mux default-handler)))
      (for-each (cut apply http-register-handler httpd <>) handlers)
      (thread-join! httpd))))

(def (main . args)
  (write ["heroku-example-gerbil" . args]) (newline)
  (call-with-getopt server-main args
    program: "server"
    help: "A example heroku server in Gerbil Scheme"
    (option 'address "-a" "--address"
            help: "server address"
            default: #f)
    (option 'data-dir "-d" "--data-dir"
            help: "data directory"
            default: #f)
    (option 'database "-D" "--database"
            help: "database URL"
            default: #f)
    (option 'url "-U" "--url"
            help: "official URL being served"
            default: #f)))

(def (server-main opt)
  (run (or (hash-get opt 'address)
           "0.0.0.0:8080")
       (or (hash-get opt 'data-dir)
           (current-directory))
       (or (hash-get opt 'database)
           (getenv "DATABASE_URL" #f)
           (error "No database specified"))
       (or (hash-get opt 'url)
           "/")))
