### -----------------------
# --- Building
### -----------------------

# first is default target when running "make" without args
build: ##- Default 'make' target: swagger, go-generate, go-format, go-build and lint.
	@$(MAKE) build-pre
	@$(MAKE) go-format
	@$(MAKE) go-build
	@$(MAKE) lint

# useful to ensure that everything gets resetuped from scratch
all: clean init ##- Runs all of our common make targets: clean, init, build and test.
	@$(MAKE) build
	@$(MAKE) test

info: iinfo-handlers info-go ##- Prints info about spec db, handlers, and go.mod updates, module-name and current go version.


info-handlers: ##- (opt) Prints info about handlers.
	@echo "[handlers]" > tmp/.info-handlers
	@gsdev handlers check --print-all >> tmp/.info-handlers
	@echo "" >> tmp/.info-handlers
	@cat tmp/.info-handlers

info-go: ##- (opt) Prints go.mod updates, module-name and current go version.
	@echo "[go.mod]" > tmp/.info-go
	@$(MAKE) get-go-outdated-modules >> tmp/.info-go
	@$(MAKE) info-module-name >> tmp/.info-go
	@go version >> tmp/.info-go
	@cat tmp/.info-go

lint: check-gen-dirs check-script-dir check-handlers check-embedded-modules-go-not go-lint  ##- Runs golangci-lint and make check-*.

# these recipies may execute in parallel
build-pre: swagger ##- (opt) Runs pre-build related targets (swagger, go-generate).
	@$(MAKE) go-generate

go-format: ##- (opt) Runs go format.
	go fmt ./...

go-build: ##- (opt) Runs go build.
	go build -ldflags $(LDFLAGS) -o bin/app

go-lint: ##- (opt) Runs golangci-lint.
	golangci-lint run --timeout 5m

go-generate: ##- (opt) Generates the internal/api/handlers/handlers.go binding.
	gsdev handlers gen

check-handlers: ##- (opt) Checks if implemented handlers match their spec (path).
	gsdev handlers check

# https://golang.org/pkg/cmd/go/internal/generate/
# To convey to humans and machine tools that code is generated,
# generated source should have a line that matches the following
# regular expression (in Go syntax):
#    ^// Code generated .* DO NOT EDIT\.$
check-gen-dirs: ##- (opt) Ensures internal/models|types only hold generated files.
	@echo "make check-gen-dirs"
	@grep -R -L '^// Code generated .* DO NOT EDIT\.$$' --exclude ".DS_Store" ./internal/types/ && echo "Error: Non generated file(s) in ./internal/types!" && exit 1 || exit 0
	@grep -R -L '^// Code generated .* DO NOT EDIT\.$$' --exclude ".DS_Store" ./internal/models/ && echo "Error: Non generated file(s) in ./internal/models!" && && exit 1 || exit 0

check-script-dir: ##- (opt) Ensures all scripts/**/*.go files have the "//go:build scripts" build tag set.
	@echo "make check-script-dir"
	@grep -R --include=*.go -L '//go:build scripts' ./scripts && echo "Error: Found unset '//go:build scripts' in ./scripts/**/*.go!" && exit 1 || exit 0

# https://github.com/gotestyourself/gotestsum#format 
# w/o cache https://github.com/golang/go/issues/24573 - see "go help testflag"
# note that these tests should not run verbose by default (e.g. use your IDE for this)
# TODO: add test shuffling/seeding when landed in go v1.15 (https://github.com/golang/go/issues/28592)
# tests by pkgname
test: ##- Run tests, output by package, print coverage.
	@$(MAKE) go-test-by-pkg
	@$(MAKE) go-test-print-coverage

# tests by testname
test-by-name: ##- Run tests, output by testname, print coverage.
	@$(MAKE) go-test-by-name
	@$(MAKE) go-test-print-coverage

test-update-golden: ##- Refreshes all golden files / snapshot tests by running tests, output by package.
	@echo "Attempting to refresh all golden files / snapshot tests (TEST_UPDATE_GOLDEN=true)!"
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	@TEST_UPDATE_GOLDEN=true gotestsum --hide-summary=skipped -- -race -count=1 ./...

# note that we explicitly don't want to use a -coverpkg=./... option, per pkg coverage take precedence
go-test-by-pkg: ##- (opt) Run tests, output by package.
	gotestsum --format pkgname-and-test-fails --jsonfile /tmp/test.log -- -race -cover -count=1 -coverprofile=/tmp/coverage.out ./...

go-test-by-name: ##- (opt) Run tests, output by testname.
	gotestsum --format testname --jsonfile /tmp/test.log -- -race -cover -count=1 -coverprofile=/tmp/coverage.out ./...

go-test-print-coverage: ##- (opt) Print overall test coverage (must be done after running tests).
	@printf "coverage "
	@go tool cover -func=/tmp/coverage.out | tail -n 1 | awk '{$$1=$$1;print}'

go-test-print-slowest: ##- Print slowest running tests (must be done after running tests).
	gotestsum tool slowest --jsonfile /tmp/test.log --threshold 2s

# TODO: switch to "-m direct" after go 1.17 hits: https://github.com/golang/go/issues/40364
get-go-outdated-modules: ##- (opt) Prints outdated (direct) go modules (from go.mod). 
	@((go list -u -m -f '{{if and .Update (not .Indirect)}}{{.}}{{end}}' all) 2>/dev/null | grep " ") || echo "go modules are up-to-date."

watch-tests: ##- Watches *.go files and runs package tests on modifications.
	gotestsum --format testname --watch -- -race -count=1

test-scripts: ##- (opt) Run scripts tests (gsdev), output by package, print coverage.
	@$(MAKE) go-test-scripts-by-pkg
	@printf "coverage "
	@go tool cover -func=/tmp/coverage-scripts.out | tail -n 1 | awk '{$$1=$$1;print}'

go-test-scripts-by-pkg: ##- (opt) Run scripts tests (gsdev), output by package.
	gotestsum --format pkgname-and-test-fails --jsonfile /tmp/test.log -- $$(go list -tags scripts ./... | grep "${GO_MODULE_NAME}/scripts") -tags scripts -race -cover -count=1 -coverprofile=/tmp/coverage-scripts.out ./...

### -----------------------
# --- Initializing
### -----------------------

init: ##- Runs make modules, tools and tidy.
	@$(MAKE) modules
	@$(MAKE) tools
	@$(MAKE) tidy

# cache go modules (locally into .pkg)
modules: ##- (opt) Cache packages as specified in go.mod.
	go mod download

# https://marcofranssen.nl/manage-go-tools-via-go-modules/
tools: ##- (opt) Install packages as specified in tools.go.
	@cat tools.go | grep _ | awk -F'"' '{print $$2}' | xargs -P $$(nproc) -L 1 -tI % go install %

tidy: ##- (opt) Tidy our go.sum file.
	go mod tidy

### -----------------------
# --- Swagger
### -----------------------

swagger: ##- Runs make swagger-concat and swagger-server.
	@$(MAKE) swagger-concat
	@$(MAKE) swagger-server

# https://goswagger.io/usage/mixin.html
# https://goswagger.io/usage/flatten.html
swagger-concat: ##- (opt) Regenerates api/swagger.yml based on api/paths/*.
	@echo "make swagger-concat"
	@rm -rf api/tmp
	@mkdir -p api/tmp
	@swagger mixin \
		--output=api/tmp/tmp.yml \
		--format=yaml \
		--keep-spec-order \
		api/config/main.yml api/paths/* \
		-q
	@swagger flatten api/tmp/tmp.yml \
		--output=api/swagger.yml \
		--format=yaml \
		-q
	@sed -i '1s@^@# // Code generated by "make swagger"; DO NOT EDIT.\n@' api/swagger.yml

# https://goswagger.io/generate/server.html
# Note that we first flag all files to delete (as previously generated), regenerate, then delete all still flagged files
# This allows us to ensure that any filewatchers (VScode) don't panic as these files are removed.
# --keep-spec-order is broken (/tmp spec resolving): https://github.com/go-swagger/go-swagger/issues/2216
swagger-server: ##- (opt) Regenerates internal/types based on api/swagger.yml.
	@echo "make swagger-server"
	@grep -R -L '^// Code generated .* DO NOT EDIT\.$$$$' ./internal/types \
		| xargs sed -i '1s#^#// DELETE ME; DO NOT EDIT.\n#'
	@swagger generate server \
		--allow-template-override \
		--template-dir=api/templates \
		--spec=api/swagger.yml \
		--server-package=internal/types \
		--model-package=internal/types \
		--exclude-main \
		--config-file=api/config/go-swagger-config.yml \
		-q
	@find internal/types -type f -exec grep -q '^// DELETE ME; DO NOT EDIT\.$$' {} \; -delete

watch-swagger: ##- Watches *.yml|yaml|gotmpl files in /api and runs 'make swagger' on modifications.
	@echo "Watching /api/**/*.yml|yaml|gotmpl. Use Ctrl-c to stop a run or exit."
	watchexec -p -w api -i tmp -i api/swagger.yml --exts yml,yaml,gotmpl $(MAKE) swagger

### -----------------------
# --- Binary checks
### -----------------------

# Got license issues with some dependencies? Provide a custom lichen --config
# see https://github.com/uw-labs/lichen#config 
get-licenses: ##- Prints licenses of embedded modules in the compiled bin/app.
	lichen bin/app

get-embedded-modules: ##- Prints embedded modules in the compiled bin/app.
	go version -m -v bin/app

get-embedded-modules-count: ##- (opt) Prints count of embedded modules in the compiled bin/app.
	go version -m -v bin/app | grep $$'\tdep' | wc -l

check-embedded-modules-go-not: ##- (opt) Checks embedded modules in compiled bin/app against go.not, throws on occurrence.
	@echo "make check-embedded-modules-go-not"
	@(mkdir -p tmp 2> /dev/null && go version -m -v bin/app > tmp/.modules)
	grep -f go.not -F tmp/.modules && (echo "go.not: Found disallowed embedded module(s) in bin/app!" && exit 1) || exit 0

### -----------------------
# --- gRCP
### -----------------------
grpc:
	protoc --go_out=. --go-grpc_out=. api/grpc/*.proto


### -----------------------
# --- Git related
### -----------------------

# This is the default upstream go-starter branch we will use for our comparisons.
# You may use a different tag/branch/commit like this:
# - Merge with a specific tag, e.g. `go-starter-2021-10-19`: `GIT_GO_STARTER_TARGET=go-starter-2021-10-19 make git-merge-go-starter`
# - Merge with a specific branch, e.g. `mr/housekeeping`: `GIT_GO_STARTER_TARGET=go-starter/mr/housekeeping make git-merge-go-starter` (heads up! it's `go-starter/<branchname>`)
# - Merge with a specific commit, e.g. `e85bedb9`: `GIT_GO_STARTER_TARGET=e85bedb94c3562602bc23d2bfd09fca3b13d1e02 make git-merge-go-starter`
GIT_GO_STARTER_TARGET ?= go-starter/master
GIT_GO_STARTER_BASE ?= $(GIT_GO_STARTER_TARGET:go-starter/%=%)

git-fetch-go-starter: ##- (opt) Fetches upstream GIT_GO_STARTER_TARGET (creating git remote 'go-starter').
	@echo "GIT_GO_STARTER_TARGET=${GIT_GO_STARTER_TARGET} GIT_GO_STARTER_BASE=${GIT_GO_STARTER_BASE}"
	@git config remote.go-starter.url >&- || git remote add go-starter https://github.com/allaboutapps/go-starter.git
	@git fetch go-starter ${GIT_GO_STARTER_BASE}

git-compare-go-starter: ##- (opt) Compare upstream GIT_GO_STARTER_TARGET to HEAD displaying commits away and git log.
	@$(MAKE) git-fetch-go-starter
	@echo "Commits away from upstream go-starter ${GIT_GO_STARTER_TARGET}:"
	git --no-pager rev-list --pretty=oneline --left-only --count ${GIT_GO_STARTER_TARGET}...HEAD
	@echo ""
	@echo "Git log:"
	git --no-pager log --left-only --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s" --abbrev-commit --count ${GIT_GO_STARTER_TARGET}...HEAD

git-merge-go-starter: ##- Merges upstream GIT_GO_STARTER_TARGET into current HEAD.
	@$(MAKE) git-compare-go-starter
	@(echo "" \
		&& echo "Attempting to execute 'git merge --no-commit --no-ff --allow-unrelated-histories ${GIT_GO_STARTER_TARGET}' into your current HEAD." \
		&& echo -n "Are you sure? [y/N]" \
		&& read ans && [ $${ans:-N} = y ]) || exit 1
	git merge --no-commit --no-ff --allow-unrelated-histories ${GIT_GO_STARTER_TARGET} || true
	@echo "Done. We recommend to run 'make force-module-name' to automatically fix all import paths."

### -----------------------
# --- Helpers
### -----------------------

clean: ##- Cleans ./tmp and ./api/tmp folder.
	@echo "make clean"
	@rm -rf tmp 2> /dev/null
	@rm -rf api/tmp 2> /dev/null

get-module-name: ##- Prints current go module-name (pipeable).
	@echo "${GO_MODULE_NAME}"

info-module-name: ##- (opt) Prints current go module-name.
	@echo "go module-name: '${GO_MODULE_NAME}'"

set-module-name: ##- Wizard to set a new go module-name.
	@rm -f tmp/.modulename
	@$(MAKE) info-module-name
	@echo "Enter new go module-name:" \
		&& read new_module_name \
		&& echo "new go module-name: '$${new_module_name}'" \
		&& echo -n "Are you sure? [y/N]" \
		&& read ans && [ $${ans:-N} = y ] \
		&& echo -n "Please wait..." \
		&& find . -not -path '*/\.*' -not -path './Makefile' -type f -exec sed -i "s|${GO_MODULE_NAME}|$${new_module_name}|g" {} \; \
		&& echo "new go module-name: '$${new_module_name}'!"
	@rm -f tmp/.modulename

force-module-name: ##- Overwrite occurrences of 'allaboutapps.dev/aw/go-starter' with current go module-name.
	find . -not -path '*/\.*' -not -path './Makefile' -type f -exec sed -i "s|allaboutapps.dev/aw/go-starter|${GO_MODULE_NAME}|g" {} \;

get-go-ldflags: ##- (opt) Prints used -ldflags as evaluated in Makefile used in make go-build
	@echo $(LDFLAGS)

# https://gist.github.com/prwhite/8168133 - based on comment from @m000
help: ##- Show common make targets.
	@echo "usage: make <target>"
	@echo "note: use 'make help-all' to see all make targets."
	@echo ""
	@sed -e '/#\{2\}-/!d; s/\\$$//; s/:[^#\t]*/@/; s/#\{2\}- *//' $(MAKEFILE_LIST) | grep --invert "(opt)" | sort | column -t -s '@'

help-all: ##- Show all make targets.
	@echo "usage: make <target>"
	@echo "note: make targets flagged with '(opt)' are part of a main target."
	@echo ""
	@sed -e '/#\{2\}-/!d; s/\\$$//; s/:[^#\t]*/@/; s/#\{2\}- *//' $(MAKEFILE_LIST) | sort | column -t -s '@'

### -----------------------
# --- Make variables
### -----------------------

# only evaluated if required by a recipe
# http://make.mad-scientist.net/deferred-simple-variable-expansion/

# go module name (as in go.mod)
GO_MODULE_NAME = $(eval GO_MODULE_NAME := $$(shell \
	(mkdir -p tmp 2> /dev/null && cat tmp/.modulename 2> /dev/null) \
	|| (gsdev modulename 2> /dev/null | tee tmp/.modulename) || echo "unknown" \
))$(GO_MODULE_NAME)

# https://medium.com/the-go-journey/adding-version-information-to-go-binaries-e1b79878f6f2
ARG_COMMIT = $(eval ARG_COMMIT := $$(shell \
	(git rev-list -1 HEAD 2> /dev/null) \
	|| (echo "unknown") \
))$(ARG_COMMIT)

ARG_BUILD_DATE = $(eval ARG_BUILD_DATE := $$(shell \
	(date -Is 2> /dev/null || date 2> /dev/null || echo "unknown") \
))$(ARG_BUILD_DATE)

# https://www.digitalocean.com/community/tutorials/using-ldflags-to-set-version-information-for-go-applications
LDFLAGS = $(eval LDFLAGS := "\
-X '$(GO_MODULE_NAME)/internal/config.ModuleName=$(GO_MODULE_NAME)'\
-X '$(GO_MODULE_NAME)/internal/config.Commit=$(ARG_COMMIT)'\
-X '$(GO_MODULE_NAME)/internal/config.BuildDate=$(ARG_BUILD_DATE)'\
")$(LDFLAGS)

### -----------------------
# --- Special targets
### -----------------------

# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html
# https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
# ignore matching file/make rule combinations in working-dir
.PHONY: test help

# https://unix.stackexchange.com/questions/153763/dont-stop-makeing-if-a-command-fails-but-check-exit-status
# https://www.gnu.org/software/make/manual/html_node/One-Shell.html
# required to ensure make fails if one recipe fails (even on parallel jobs) and on pipefails
.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS = -cEeuo pipefail
