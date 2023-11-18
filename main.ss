;; -*- Gerbil -*-
;;; Simple web server:
;; - Serves a main page (to demo basic service), and
;; - Shortens URLs (to demo use of a database).
;;
;; Code originally based on vyzo's example in gerbil/src/tutorial/httpd/simpled.ss

(import
  (only-in :gerbil/gambit random-integer)
  (only-in :std/db/dbi sql-connect sql-eval sql-eval-query)
  (only-in :std/db/postgresql postgresql-connect) ; parse-postgres-database-url
  (only-in :std/getopt call-with-getopt option)
  (only-in :std/misc/string string-trim-prefix)
  (only-in :std/net/httpd
           start-http-server! make-default-http-mux http-register-handler
           http-request-url http-request-client http-request-path http-request-body
           http-response-write http-response-file
           http-response-write-condition Not-Found)
  (only-in :std/net/address inet-address->string)
  (only-in :std/net/ssl insecure-client-ssl-context)
  (only-in :std/net/uri form-url-decode)
  (only-in :std/pregexp pregexp-match)
  (only-in :std/source this-source-content)
  (only-in :std/sugar hash try catch)
  (only-in :std/xml/sxml-to-xml sxml->xhtml-string)
  (only-in :std/text/utf8 utf8->string))
(export main)

(def data-root (make-parameter #f))
(def server-url (make-parameter "/"))
(def database-connection (make-parameter #f))

;; / - handler for the main page
;; NB: The SXML syntax is a bit awkward, but it's the de-facto "standard" in Scheme.
;; TODO: port Racket's scribble-html to Gerbil and use it instead.
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

;; Generic code for recognizing intended content encoding from file extensions
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
    (if (and content-type (file-exists? file-path))
      (http-response-file res `(("Content-Type" . ,content-type)) file-path)
      (http-response-write-condition res Not-Found))))

;; Page that handles URL shortening
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

;; SXML HTML form for the shorten functionality
(def (shorten-form)
  '(form (@ (action "/shorten") (method "post"))
     (p "As a simple demo for using a database, you can create persistent short URLs.")
     (p (label "Full URL: " (input (@ (name "url")))))
     (p (input (@ (type "submit") (value "Shorten!"))))))

;; In-memory cache of the shortened URL database
(def short-urls (hash))
(def short-urls-mutex (make-mutex "shorten"))

#|
;; Version without a database. Remove at some point.
(def (make-short-url url)
  (with-lock short-urls-mutex
    (lambda ()
      (def name (new-short-name))
      (hash-put! short-urls name url)
      name)))
(def (unshorten-url short)
  (hash-get short-urls short))
(def (new-short-name)
  ;; Start with two-character strings: reserve one-character paths for future uses.
  (let (s (as-string (random-url-char) (random-url-char)))
    (while (hash-key? short-urls s)
      (set! s (as-string s (random-url-char))))
    s))
|#

;; Database definition for the shortened url table
(def (pgsql-schema)
  "CREATE TABLE IF NOT EXISTS shorten_url (
     short varchar(100) NOT NULL,
     long varchar(2048) NOT NULL,
     PRIMARY KEY(short));")

;; Generating random characters for the shortened URL
(def short-url-chars
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
(def (random-url-char)
  (string-ref short-url-chars (random-integer 64)))

;; Make increasingly longer URLs until a fresh entry is found
(def (make-short-url url)
  (let loop ((short (as-string (random-url-char) (random-url-char))))
    (def (retry) (loop (as-string short (random-url-char))))
    (if (with-lock short-urls-mutex (cut hash-key? short-urls short))
      (retry)
      (try (sql-eval (database-connection)
                     "INSERT INTO shorten_url (short, long) VALUES ($1, $2)" short url)
           (with-lock short-urls-mutex (cut hash-put! short-urls short url))
           short
           (catch (e)
             (display-exception e)
             (retry))))))

;; Find a long URL from the shortened version
(def (unshorten-url short)
  (or (with-lock short-urls-mutex (cut hash-get short-urls short))
      (try (match (sql-eval-query (database-connection)
                                  "SELECT long FROM shorten WHERE short = $1" short)
             ([(vector long)] long)
             (else #f))
           (catch (e) (display-exception e) #f))))

;; TODO: use the one from std/db/postgres once committed
;; Parse the DATABASE_URL from heroku into a list of server database user pass
;; : String -> (Tuple String String String String)
(def (parse-postgres-database-url url)
  (match (pregexp-match "^postgres://(([^:/@]+)(:([^:/@]*))?@)?([^:/@]+)(:([0-9]+))?/(.+)$" url)
    ([_ userpass user xpass pass host xport port database]
     [host (and port (string->number port)) database (and userpass user) (and xpass pass)])
    (else #f)))

;; default: unshorten, or else 404
(def (default-handler req res)
  (cond
   ;; Unshorten URL
   ((unshorten-url (string-trim-prefix "/" (http-request-path req)))
    => (lambda (url)
         (http-response-write
          res 307 `(("Content-Type" . "text/html")
                    ("Location" . ,url))
          (sxml->xhtml-string `(html (body "Moved to: " (a (@ (href ,url)) ,url)))))))
   ;; Not found
   (else
    (http-response-write
     res 404 '(("Content-Type" . "text/plain"))
     "The gerbils couldn't find the page you're looking for."))))

;; List of handlers for our http service
(def handlers
  [["/" root-handler]
   ["/main.ss" file-handler]
   ["/gerbil.png" gerbil.png-handler]
   ["/shorten" shorten-handler]])

(def (run address data-dir database-url server-url/)

  ;; Exclude paths with handlers from short-urls table
  (for-each (match <> ([path . _] (let (taken (string-trim-prefix "/" path))
                                    (hash-put! short-urls taken taken))))
            handlers)

  ;; Open the SQL database connection
  (def connection
    (with ([host port database user passwd]
           (or (parse-postgres-database-url database-url)
               (error "Invalid database url" database-url)))
      (sql-connect postgresql-connect
                   host: host port: 5432 user: user db: database passwd: passwd
                   ssl?: (if (equal? host "localhost") 'try #t)
                   ;; TODO: investigate why the default (secure) context won't work with Heroku
                   ssl-context: (insecure-client-ssl-context))))

  ;; Initialize the Schema, if not done already
  (sql-eval connection (pgsql-schema))

  ;; Bind parameters so handlers can see and use them
  (parameterize ((data-root data-dir)
                 (server-url server-url/)
                 (database-connection connection))
    ;; Start the HTTP daemon
    (def httpd (start-http-server! address mux: (make-default-http-mux default-handler)))

    ;; Register the handlers
    (for-each (cut apply http-register-handler httpd <>) handlers)

    ;; Wait for it to end
    (thread-join! httpd)))

;; Main entry point from the REPL
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

;; Main entry point from the CLI
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
