#   Copyright The containerd Authors.

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# Set an output prefix, which is the local directory if not specified
PREFIX?=$(shell pwd)

# Used to populate version variable in main package.
VERSION=$(shell git describe --match 'v[0-9]*' --dirty='.m' --always)

GO_LDFLAGS=-ldflags "-X `go list -mod=vendor ./version`.Version=$(VERSION)"

PKG=github.com/containerd/continuity

PACKAGES=$(shell go list -mod=vendor ./... | grep -v /vendor/)
TEST_REQUIRES_ROOT_PACKAGES=$(filter \
    ${PACKAGES}, \
    $(shell \
    for f in $$(git grep -l testutil.RequiresRoot | grep -v Makefile); do \
        d="$$(dirname $$f)"; \
        [ "$$d" = "." ] && echo "${PKG}" && continue; \
        echo "${PKG}/$$d"; \
    done | sort -u) \
    )

.PHONY: clean all lint build test binaries
.DEFAULT: default

all: AUTHORS clean lint build test binaries

AUTHORS: .mailmap .git/HEAD
	 git log --format='%aN <%aE>' | sort -fu > $@

# This only needs to be generated by hand when cutting full releases.
version/version.go:
	./version/version.sh > $@

${PREFIX}/bin/continuity: version/version.go $(shell find . -type f -name '*.go')
	@echo "+ $@"
	@go build -mod=vendor -o $@ ${GO_LDFLAGS}  ${GO_GCFLAGS} ./cmd/continuity

generate:
	go generate -mod=vendor $(PACKAGES)

lint:
	@echo "+ $@"
	@golangci-lint run

build:
	@echo "+ $@"
	@go build -mod=vendor -v ${GO_LDFLAGS} $(PACKAGES)

test:
	@echo "+ $@"
	@go test -mod=vendor $(PACKAGES)

root-test:
	@echo "+ $@"
	@go test ${TEST_REQUIRES_ROOT_PACKAGES} -test.root

test-compile:
	@echo "+ $@"
	@for pkg in $(PACKAGES); do go test -mod=vendor -c $$pkg; done

binaries: ${PREFIX}/bin/continuity
	@echo "+ $@"
	@if [ x$$GOOS = xwindows ]; then echo "+ continuity -> continuity.exe"; mv ${PREFIX}/bin/continuity ${PREFIX}/bin/continuity.exe; fi

clean:
	@echo "+ $@"
	@rm -rf "${PREFIX}/bin/continuity" "${PREFIX}/bin/continuity.exe"

