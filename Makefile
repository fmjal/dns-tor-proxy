SHELL := /bin/bash
DESTDIR := /
EXTLDFLAGS := -static -s
LDFLAGS := -buildid='' -extldflags '${EXTLDFLAGS}'
#-extldflags=${EXTLDFLAGS}
GO_BUILD := garble -tiny -seed=random -literals build -v
TEMPDIR :=  $(shell mktemp -d)
.PHONY: all build clean help install garble depends

all: build install clean ## Default target, runs the build

depends:
	export GOPROXY=on;
	export GO111MODULE=on;\
	# Downloading go modules
	go mod tidy 

build: depends
	export GO111MODULE=on; \
	# Windows builds
	CGO_ENABLED=0 GOOS=windows GOARCH=386 ${GO_BUILD}-ldflags="${LDFLAGS}" -o bin/dns-tor-proxy-i386.exe cmd/dns-tor-proxy/main.go
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 ${GO_BUILD}-ldflags="${LDFLAGS}" -o bin/dns-tor-proxy-amd64.exe cmd/dns-tor-proxy/main.go
	CGO_ENABLED=0 GOOS=windows GOARCH=arm64 ${GO_BUILD}-ldflags="${LDFLAGS}" -o bin/dns-tor-proxy-arm64.exe cmd/dns-tor-proxy/main.go
	# Linux builds
	CGO_ENABLED=0 GOOS=linux GOARCH=386 ${GO_BUILD}-ldflags="${LDFLAGS}" -o bin/dns-tor-proxy-linux-i386 cmd/dns-tor-proxy/main.go
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 ${GO_BUILD}-ldflags="${LDFLAGS}" -o bin/dns-tor-proxy-linux-amd64 cmd/dns-tor-proxy/main.go
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 ${GO_BUILD}-ldflags="${LDFLAGS}" -o bin/dns-tor-proxy-linux-arm64 cmd/dns-tor-proxy/main.go
	# Android and macOS builds
	CGO_ENABLED=0 GOOS=android GOARCH=arm64 ${GO_BUILD}-ldflags="" -o bin/dns-tor-proxy-android-arm64 cmd/dns-tor-proxy/main.go
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 ${GO_BUILD}-ldflags="${LDFLAGS}" -o bin/dns-tor-proxy-darwin-arm64 cmd/dns-tor-proxy/main.go
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 ${GO_BUILD}-ldflags="${LDFLAGS}" -o bin/dns-tor-proxy-darwin-amd64 cmd/dns-tor-proxy/main.go
	./scripts/compress.sh

install: build ## Install the appropriate binary based on the host architecture and OS
	@os=$$(uname -s | tr '[:upper:]' '[:lower:]'); \
	arch=$$(uname -m); \
	if [ "$$os" = "linux" ]; then \
		if [ "$$arch" = "x86_64" ]; then \
			sudo install -m 0755 bin/dns-tor-proxy-linux-amd64 /usr/local/bin/dns-tor-proxy; \
		elif [ "$$arch" = "i386" ] || [ "$$arch" = "i686" ]; then \
			sudo install -m 0755 bin/dns-tor-proxy-linux-i386 /usr/local/bin/dns-tor-proxy; \
		elif [ "$$arch" = "aarch64" ]; then \
			sudo install -m 0755 bin/dns-tor-proxy-linux-arm64 /usr/local/bin/dns-tor-proxy; \
		else \
			echo "Unsupported architecture: $$arch"; exit 1; \
		fi; \
		echo "Installing as systemd service..."; \
		echo "Installing dependencies..."; \
		sudo apt-get install -yqq systemd-resolved tor 2> /dev/null > /dev/null; \
		sudo install -m 0644 ./files/dns-tor-proxy.service ${DESTDIR}/lib/systemd/system/; \
		sudo mkdir -p ${DESTDIR}/etc/permission-hardener.d; \
		sudo mkdir -p ${DESTDIR}/etc/systemd/resolved.conf.d; \
		sudo install -m 0644 ./files/resolved.conf ${DESTDIR}/etc/systemd/; \
		sudo install -m 0644 ./files/00-dns-tor-proxy.conf ${DESTDIR}/etc/systemd/resolved.conf.d; \
        sudo install -m 0644 ./files/99-dns-tor-proxy.conf ${DESTDIR}/etc/permission-hardener.d; \
		sudo systemctl enable systemd-resolved dns-tor-proxy; \
		sudo systemctl daemon-reload; \
		sudo systemctl restart dns-tor-proxy systemd-resolved; \
	elif [ "$$os" = "darwin" ]; then \
		if [ "$$arch" = "x86_64" ]; then \
			sudo install -m 0755 bin/dns-tor-proxy-darwin-amd64 /usr/local/bin/dns-tor-proxy; \
		elif [ "$$arch" = "arm64" ]; then \
			sudo install -m 0755 bin/dns-tor-proxy-darwin-arm64 /usr/local/bin/dns-tor-proxy; \
		else \
			echo "Unsupported architecture: $$arch"; exit 1; \
		fi; \
	else \
		echo "Unsupported OS: $$os"; exit 1; \
	fi

clean:
	rm -f ./bin/dns-tor-proxy*

help:
	@printf "Makefile for developing and building dns-tor-proxy\n"
	@printf "Subcommands:\n"
	@awk 'BEGIN {FS = ":.*?## "} /^[0-9a-zA-Z_-]+:.*?## / {printf "%s : %s\n", $$1, $$2}' $(MAKEFILE_LIST) \
		| sort \
		| column -s ':' -t
