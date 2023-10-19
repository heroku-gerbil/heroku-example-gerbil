# Example of a Heroku application written in Gerbil Scheme

This is an example [Heroku](https://heroku.com) app
written in [Gerbil Scheme](https://cons.io).
See the github repositories
[for this app](https://github.com/heroku-gerbil/heroku-example-gerbil) and
[for the Gerbil buildpack](https://github.com/heroku-gerbil/heroku-buildpack-gerbil).

Test it at home with:
```shell
gxpkg deps --install
gxpkg build
~/.gerbil/bin/heroku-example-gerbil -d $PWD &
xdg-open http://localhost:8080
```

Test it on Heroku with:
```
heroku create heroku-example-gerbil --buildpack fare/gerbil
```
