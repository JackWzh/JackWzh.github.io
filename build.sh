rm -rf _site 

rm -rf .sass-cache

bundle exec jekyll serve --incremental --open-url --trace --force_polling --future 