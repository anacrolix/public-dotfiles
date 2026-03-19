#!/usr/bin/make -f
SHELL = /bin/bash
SRC = $(HOME)/src
GOROOT = $(SRC)/go
SCMUSER = Matt Joiner <anacrolix@gmail.com>
# export GOROOT_BOOTSTRAP = $(SRC)/go1.4
my-go-packages = github.com/anacrolix/... bitbucket.org/anacrolix/...
GO = go
GOM = gom
# export GO111MODULE ?= on

default: test-my-go

update-go: pull-go $(GOROOT)/anacrolix.build

pull-go: git-config $(GOROOT)
	@cd $(GOROOT) \
		&& git pull -q \
		&& have=`cat anacrolix.build 2> /dev/null` want=`git describe --tags` \
		&& echo 'have:' $$have \
		&& echo 'want:' $$want \
		&& { [ "$$have" == "$$want" ] || rm -f anacrolix.build; }

$(GOROOT)/bin/go: $(GOROOT)/src/anacrolix.build

$(GOROOT)/anacrolix.build: #$(GOROOT_BOOTSTRAP)/bin/go
	cd $(GOROOT)/src && time nice ./make.bash
	cd $(GOROOT) && git describe --tags > anacrolix.build

go-tools:
	go get -u -v \
		golang.org/x/tools/cmd/godoc \
		golang.org/x/tools/cmd/guru \
		golang.org/x/tools/cmd/gorename \
		honnef.co/go/tools/cmd/unused \
		github.com/rogpeppe/sortimports \
		golang.org/x/tools/cmd/goimports

$(SRC):
	mkdir -p $@

$(GOROOT): | $(SRC)
	cd $(SRC) \
		&& git clone https://github.com/anacrolix/go.git

$(GOROOT_BOOTSTRAP): | $(GOROOT) $(SRC)
	cd $(GOROOT) \
		&& git branch -f -t go1.4 origin/release-branch.go1.4
	cd $(SRC) \
		&& git clone --single-branch -b go1.4 go go1.4

$(GOROOT_BOOTSTRAP)/bin/go: | $(GOROOT_BOOTSTRAP)
	cd $(GOROOT_BOOTSTRAP)/src \
		&& ./make.bash 2> /dev/null

test-anacrolix-go-packages:
	go test -i $(my-go-packages)
	go test $(my-go-packages)

git-config-ssh-insteadof-https:
	git config --global url."git@$(DOMAIN):".insteadOf "https://$(DOMAIN)/"

hg-config-add-username:
	echo '[ui]' >> ~/.hgrc
	echo 'username = ' '$(SCMUSER)' >> ~/.hgrc

git-config:
	@git config --global user.email "anacrolix@gmail.com"
	@git config --global user.name "Matt Joiner"
	@git config --global credential.helper cache

	@# so go get works on private repos
	@# git config --global url."https://github.com".insteadOf git@github.com

	@# squelch new git 2.0 push model warning
	@git config --global push.default simple

test-my-go:
	nice $(GO) test -race $(my-go-packages)
	nice $(GO) test $(my-go-packages)
	CGO_ENABLED=0 nice $(GO) test github.com/anacrolix/torrent github.com/anacrolix/dht/...
	$(GO) test $(my-go-packages) -bench . -run @
	$(GOM) build $(my-go-packages)

