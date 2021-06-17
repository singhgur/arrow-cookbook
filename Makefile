all: html


html:   py r
	@echo "\n\n>>> Cookbooks Available in ./build <<<"


test:   pytest rtest


help:
	@echo "make all         Build cookbook for all platforms in HTML, will be available in ./build"
	@echo "make test        Test cookbook for all platforms."
	@echo "make py          Build the Cookbook for Python only."
	@echo "make r           Build the Cookbook for R only."
	@echo "make pytest      Verify the cookbook for Python only."
	@echo "make rtest       Verify the cookbook for R only."


pydeps:
	@echo ">>> Installing Python Dependencies <<<\n"
	cd python && pip install -r requirements.txt


py: pydeps
	@echo ">>> Building Python Cookbook <<<\n"
	cd python && make html
	mkdir -p build/py
	cp -r python/build/html/* build/py


pytest: pydeps
	@echo ">>> Testing Python Cookbook <<<\n"
	cd python && make doctest

rdeps:
	@echo ">>> Installing R Dependencies <<<\n"
	R -s -e 'if (!require("pacman")) install.packages("pacman")'
	R -s -e 'pacman::p_load("testthat", "bookdown", "xfun", "knitr", "purrr", "remotes")'
	R -s -e 'pacman::p_load_gh("rmflight/testrmd", "apache/arrow/r")'

r: rdeps
	@echo ">>> Building R Cookbook <<<\n"
	R -s -e 'bookdown::render_book("./r/content", output_format = "bookdown::gitbook")'
	mkdir -p build/r
	cp -r r/content/_book/* build/r

rtest: rdeps
	@echo ">>> Testing R Cookbook <<<\n"
	cd ./r && Rscript ./test.R


