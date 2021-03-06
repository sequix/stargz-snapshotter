#!/bin/bash

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

set -euo pipefail

REGISTRY_HOST=registry-optimize
DUMMYUSER=dummyuser
DUMMYPASS=dummypass
ORG_IMAGE_TAG="${REGISTRY_HOST}:5000/test:org$(date '+%M%S')"
OPT_IMAGE_TAG="${REGISTRY_HOST}:5000/test:opt$(date '+%M%S')"

RETRYNUM=100
RETRYINTERVAL=1
TIMEOUTSEC=180
function retry {
    local SUCCESS=false
    for i in $(seq ${RETRYNUM}) ; do
        if eval "timeout ${TIMEOUTSEC} ${@}" ; then
            SUCCESS=true
            break
        fi
        echo "Fail(${i}). Retrying..."
        sleep ${RETRYINTERVAL}
    done
    if [ "${SUCCESS}" == "true" ] ; then
        return 0
    else
        return 1
    fi
}

function prepare_context {
    local CONTEXT_DIR="${1}"
    cat <<EOF > "${CONTEXT_DIR}/Dockerfile"
FROM scratch

COPY ./a.txt ./b.txt accessor /
COPY ./c.txt ./d.txt /
COPY ./e.txt /

ENTRYPOINT ["/accessor"]

EOF
    for SAMPLE in "a" "b" "c" "d" "e" ; do
        echo "${SAMPLE}" > "${CONTEXT_DIR}/${SAMPLE}.txt"
    done
    mkdir -p "${GOPATH}/src/test/test" && \
        cat <<'EOF' > "${GOPATH}/src/test/test/main.go"
package main

import (
	"os"
)

func main() {
	targets := []string{"/a.txt", "/c.txt"}
	for _, t := range targets {
		f, err := os.Open(t)
		if err != nil {
			panic("failed to open file")
		}
		f.Close()
	}
}
EOF
    GO111MODULE=off go build -ldflags '-extldflags "-static"' -o "${CONTEXT_DIR}/accessor" "${GOPATH}/src/test/test"
}

echo "Connecting to the docker server..."
retry ls /docker/client/cert.pem /docker/client/ca.pem
mkdir -p /root/.docker/ && cp /docker/client/* /root/.docker/
retry docker version

echo "Logging into the registry..."
cp /auth/certs/domain.crt /usr/local/share/ca-certificates
update-ca-certificates
retry docker login "${REGISTRY_HOST}:5000" -u "${DUMMYUSER}" -p "${DUMMYPASS}"

echo "Building sample image for testing..."
CONTEXT_DIR=$(mktemp -d)
prepare_context "${CONTEXT_DIR}"

echo "Preparing sample image..."
tar zcv -C "${CONTEXT_DIR}" . \
    | docker build -t "${ORG_IMAGE_TAG}" - \
    && docker push "${ORG_IMAGE_TAG}"

echo "Optimizing image..."
WORKING_DIR=$(mktemp -d)
PREFIX=/tmp/out/ make clean
PREFIX=/tmp/out/ GO_BUILD_FLAGS="-race" make ctr-remote # Check data race
/tmp/out/ctr-remote image optimize -entrypoint='[ "/accessor" ]' "${ORG_IMAGE_TAG}" "${OPT_IMAGE_TAG}"

echo "Downloading optimized image..."
docker pull "${OPT_IMAGE_TAG}" && docker save "${OPT_IMAGE_TAG}" | tar xv -C "${WORKING_DIR}"
LAYER_0="${WORKING_DIR}/$(cat "${WORKING_DIR}/manifest.json" | jq -r '.[0].Layers[0]')"
LAYER_1="${WORKING_DIR}/$(cat "${WORKING_DIR}/manifest.json" | jq -r '.[0].Layers[1]')"
LAYER_2="${WORKING_DIR}/$(cat "${WORKING_DIR}/manifest.json" | jq -r '.[0].Layers[2]')"
tar --list -f "${LAYER_0}" | tee "${WORKING_DIR}/0-got" && \
    tar --list -f "${LAYER_1}" | tee "${WORKING_DIR}/1-got" && \
    tar --list -f "${LAYER_2}" | tee "${WORKING_DIR}/2-got"
cat <<EOF > "${WORKING_DIR}/0-want"
accessor
a.txt
.prefetch.landmark
b.txt
stargz.index.json
EOF
cat <<EOF > "${WORKING_DIR}/1-want"
c.txt
.prefetch.landmark
d.txt
stargz.index.json
EOF
cat <<EOF > "${WORKING_DIR}/2-want"
.no.prefetch.landmark
e.txt
stargz.index.json
EOF
echo "Validating tarball contents of layer 0 (base layer)..."
diff "${WORKING_DIR}/0-got" "${WORKING_DIR}/0-want"
echo "Validating tarball contents of layer 1..."
diff "${WORKING_DIR}/1-got" "${WORKING_DIR}/1-want"
echo "Validating tarball contents of layer 2..."
diff "${WORKING_DIR}/2-got" "${WORKING_DIR}/2-want"

exit 0
