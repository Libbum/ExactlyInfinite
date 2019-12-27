SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

ifeq ($(origin .RECIPEPREFIX), undefined)
  $(error This Make does not support .RECIPEPREFIX. Please use GNU Make 4.0 or later)
endif
.RECIPEPREFIX = >

serve: prodindex prodcss dist/js/init.js
> elm-live src/Main.elm -d dist -s contact.html --open -- --output=dist/js/main.js --optimize

debug: debugindex debugcss dist/js/init.js
> elm-live src/Main.elm -d dist -s contact.html --open -- --output=dist/js/main.js --debug

dist/js/init.js: src/init.js
> uglifyjs src/init.js --output dist/js/init.js

dist/js/main.js:
> elm make src/Main.elm --output=dist/js/main.js --optimize

dist/js/main.min.js: dist/js/main.js
> uglifyjs dist/js/main.js --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output=dist/js/main.min.js

prodindex: dist/contact.html
> sed -i 's/main.*js/main.min.js/' dist/contact.html

debugindex: dist/contact.html
> sed -i 's/main.*js/main.js/' dist/contact.html

prodcss: src/notifier.css
> crass src/notifier.css --optimize > dist/style/notifier.css
> crass src/front.css --optimize > dist/style/front.css

debugcss: src/notifier.css
> cp src/notifier.css dist/style/notifier.css
> cp src/front.css dist/style/front.css

build: dist/js/main.min.js prodindex prodcss dist/js/init.js
> @-rm -f dist/js/main.js
.PHONY: build

clean:
> @-rm -f dist/js/main*.js dist/style/notifier.css
.PHONY: clean

rebuild: clean build
.PHONY: rebuild

deploy: rebuild
> rsync -avr --chown=http:www --checksum --delete -e ssh dist/ KalaR:exactlyinfinite
