# Example of a Heroku application written in Gerbil Scheme

This is an example [Heroku](https://heroku.com) app
written in [Gerbil Scheme](https://cons.io).
See the github repositories
[for this app](https://github.com/heroku-gerbil/heroku-example-gerbil) and
[for the Gerbil buildpack](https://github.com/heroku-gerbil/heroku-buildpack-gerbil).

## Build and test the app locally
Build and test it at home with:
```shell
gxpkg deps --install
gxpkg build
~/.gerbil/bin/heroku-example-gerbil -d $PWD &
xdg-open http://localhost:8080
```

## Build and test the app on Heroku
Build and test it on Heroku with:
```shell
heroku create heroku-example-gerbil --buildpack fare/gerbil
git push heroku master
```
And point your browser where heroku tells you.

## TODO
Illustrate how to use the database from Gerbil,
as well as any other backend services offered by Heroku, if any.
