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

FROM golang:1.13

# mirrors
RUN echo 'deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free' >/etc/apt/sources.list && \
    echo 'deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free' >>/etc/apt/sources.list && \
    echo 'deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free' >>/etc/apt/sources.list && \
    echo 'deb https://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib non-free' >>/etc/apt/sources.list && \
    apt-get update -y && \
    echo '[https]' >>$HOME/.gitconfig && \
    echo '    proxy = http://host.docker.internal:8118' >>$HOME/.gitconfig && \
    echo '[http]' >>$HOME/.gitconfig && \
    echo '    proxy = http://host.docker.internal:8118' >>$HOME/.gitconfig && \
    export GOPROXY="https://goproxy.cn,direct" && \
    echo 'export GOPROXY="https://goproxy.cn,direct"' >>$HOME/.bashrc

# basic packages
RUN apt-get --no-install-recommends install -y libbtrfs-dev libseccomp-dev fuse \
        apt-transport-https gnupg2 software-properties-common

# runtime dependencies
RUN git clone https://github.com/opencontainers/runc $GOPATH/src/github.com/opencontainers/runc && \
    cd $GOPATH/src/github.com/opencontainers/runc && \
    git checkout d736ef14f0288d6993a1845745d6756cfc9ddd5a && \
    GO111MODULE=off make BUILDTAGS='seccomp apparmor' && \
    GO111MODULE=off make install

# download go mod here to speed up run.sh
RUN git clone https://github.com/containerd/stargz-snapshotter $GOPATH/src/github.com/containerd/stargz-snapshotter && \
    cd $GOPATH/src/github.com/containerd/stargz-snapshotter && \
    make 

RUN git clone https://github.com/containerd/containerd $GOPATH/src/github.com/containerd/containerd && \
    cd $GOPATH/src/github.com/containerd/containerd && \
    git checkout 04985039cede6aafbb7dfb3206c9c4d04e2f924d  && \
    GO111MODULE=off make && \
    GO111MODULE=off make install

# crictl
RUN git clone https://github.com/kubernetes-sigs/cri-tools $GOPATH/src/github.com/kubernetes-sigs/cri-tools && \
    cd $GOPATH/src/github.com/kubernetes-sigs/cri-tools && \
    git checkout 7c03c059b403cced3b12c62c5c1c11c5b0797193 && \
    make crictl && \
    mv _output/crictl /usr/local/bin && \
    echo 'runtime-endpoint: unix:///run/containerd/containerd.sock' >/etc/crictl.yaml && \
    echo 'image-endpoint: unix:///run/containerd/containerd.sock' >>/etc/crictl.yaml && \
    echo 'timeout: 10' >>/etc/crictl.yaml && \
    echo 'debug: true' >>/etc/crictl.yaml

# crane
RUN git clone https://github.com/google/go-containerregistry $GOPATH/src/github.com/google/go-containerregistry && \
    cd $GOPATH/src/github.com/google/go-containerregistry && \
    git checkout 5cbd060f5c9218eea992d3246fe51d7794dd6cd3 && \
    go build -o /usr/local/bin/crane cmd/crane/main.go

# bolt
RUN git clone https://github.com/etcd-io/bbolt.git $GOPATH/src/github.com/etcd-io/bblot && \
    cd $GOPATH/src/github.com/etcd-io/bblot && \
    git fetch origin +refs/pull/130/merge && \
    git checkout FETCH_HEAD && \
    go build -o /usr/local/bin/bolt cmd/bbolt/main.go

# tools
RUN apt-get --no-install-recommends install -y vim && \
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && \
    yes | ~/.fzf/install

# habit
RUN echo 'export PS1="\u@\h:\W\$ "' >>$HOME/.bashrc && \
    echo 'unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY' >>$HOME/.bashrc && \
    echo 'onproxy() {' >>$HOME/.bashrc && \
    echo '    export http_proxy="http://host.docker.internal:8118"' >>$HOME/.bashrc && \
    echo '    export https_proxy="http://host.docker.internal:8118"' >>$HOME/.bashrc && \
    echo '    export HTTP_PROXY="http://host.docker.internal:8118"' >>$HOME/.bashrc && \
    echo '    export HTTPS_PROXY="http://host.docker.internal:8118"' >>$HOME/.bashrc && \
    echo '}' >>$HOME/.bashrc && \
    echo 'offproxy() {' >>$HOME/.bashrc && \
    echo '    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY' >>$HOME/.bashrc && \
    echo '}' >>$HOME/.bashrc
