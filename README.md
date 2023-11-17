# Example of a Heroku application written in Gerbil Scheme

This is an example [Heroku](https://heroku.com) app
written in [Gerbil Scheme](https://cons.io).
See the github repositories
[for this app](https://github.com/heroku-gerbil/heroku-example-gerbil) and
[for the Gerbil buildpack](https://github.com/heroku-gerbil/heroku-buildpack-gerbil).

## Build and test the app locally
Build and test it at home with:
```shell
# If you don't have a running pgsql database yet,
# you can create one just for this test with:
mkdir -p pg/run &&
(cd pg && initdb -D db &&
  echo "unix_socket_directories = '$PWD/run'" >> db/postgresql.conf &&
  pg_ctl -D db -l logfile start )
export DATABASE_URL="postgres://${USER}@localhost/postgres"

# You can later stop the database with:
# pg_ctl -D pg/db stop

# Alternatively, you can create a heroku app and its database as below,
# then connect to its database with
# export DATABASE_URL="$(heroku config:get DATABASE_URL)"

# Compile all the dependencies (if you added any)
gxpkg deps --install

# Build the code
gxpkg build

# Run the example
~/.gerbil/bin/heroku-example-gerbil -U http://localhost:8080/ &

# With the dependencies built or in your GERBIL_LOADPATH,
# you can also run the example without compilation with e.g.:
#   gxi main.ss -U http://localhost:8080/

# Open your browser at the given URL
xdg-open http://localhost:8080
```

## Build and test the app on Heroku
Build and test it on Heroku with:
```shell
heroku create heroku-example-gerbil --buildpack fare/gerbil
heroku addons:create heroku-postgresql:mini
heroku config:set HEROKU_URL=$(heroku info -s | grep web_url= | cut -d= -f2)
git push heroku master
```
And point your browser where heroku tells you.

When you're done playing with the app, you can destroy it with:
```
heroku apps:destroy --confirm heroku-example-gerbil
```

## TODO
Illustrate how to use the database from Gerbil,
as well as any other backend services offered by Heroku, if any.
