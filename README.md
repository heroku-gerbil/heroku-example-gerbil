# Example of a Gerbil service running on Heroku

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
