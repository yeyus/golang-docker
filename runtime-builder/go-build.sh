#!/bin/bash

# Copyright 2017 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

# go-build.sh builds the Go application in the current work directory and
# generates a Dockerfile in that same directory.

set -e

workspace="$(pwd -P)"

if [[ -z "${GO_VERSION}" || -z "${BASE_DIGEST}" || -z "${BUILD_TAG}" ]]; then
    echo "Missing env variable(s): GO_VERSION='${GO_VERSION}', BASE_DIGEST='${BASE_DIGEST}', BUILD_TAG='${BUILD_TAG}'."
    exit 1
fi

export PATH=/usr/local/go/bin:"${PATH}"
export GOPATH="${workspace}"/_gopath

# Move application files into a temporary staging directory, dependencies excluded.
staging=$(mktemp -d staging.XXXX)
find . -mindepth 1 -maxdepth 1 ! -name "${staging}" ! -name "$(basename $GOPATH)" -exec mv {} "${staging}"/ \;

# Create a bin/ directory containing all the binaries needed in the final image.
mkdir bin
cd "${staging}"
go build -o "${workspace}"/bin/app -tags appenginevm

# Move application files into app subdirectory.
cd "${workspace}"
mv "${staging}" "${workspace}"/app

# Copy zoneinfo directory into workspace in order to be placed into final image.
cp -p -R /usr/share/zoneinfo "${workspace}"/zoneinfo

# Generate application Dockerfile.
cat > Dockerfile <<EOF
FROM gcr.io/distroless/base@${BASE_DIGEST}

LABEL build_tag="${BUILD_TAG}"
LABEL go_version="${GO_VERSION}"

COPY bin/ /usr/local/bin/
COPY app/ /app/
COPY zoneinfo/ /usr/share/zoneinfo/

WORKDIR /app
ENTRYPOINT ["/usr/local/bin/app"]
EOF
