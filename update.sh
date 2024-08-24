#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

# Declare versions as an associative array
declare -A versions=(
    [nginx]='1.27.1'
    [njs]='0.8.5'
    [njspkg]='1'
    [pkg]='1'
    [dynpkg]='2'
    [alpine]='3.20'
    [rev]='${NGINX_VERSION}-${PKG_RELEASE}'
    [pkgosschecksum]='b9fbdf1779186fc02aa59dd87597fe4e906892391614289a4e6eedba398a3e770347b5b07110cca8c11fa3ba85bb711626ae69832e74c69ca8340d040a465907'
    [buildtarget]='base'
)

# Generate warning header
cat <<'EOF' > "src/Dockerfile"
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#
EOF

# Append the template and replace placeholders
sed -e 's,%%ALPINE_VERSION%%,'"${versions[alpine]}"',' \
    -e 's,%%NGINX_VERSION%%,'"${versions[nginx]}"',' \
    -e 's,%%PKG_RELEASE%%,'"${versions[pkg]}"',' \
    -e 's,%%PACKAGES%%, \\\n        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \\,' \
    -e 's,%%PACKAGEREPO%%,https://nginx.org/packages/mainline/alpine/,' \
    -e 's,%%REVISION%%,'"${versions[rev]}"',' \
    -e 's,%%PKGOSSCHECKSUM%%,'"${versions[pkgosschecksum]}"',' \
    -e 's,%%BUILDTARGET%%,'"${versions[buildtarget]}"',' \
    "Dockerfile-alpine-slim.template" >> "src/Dockerfile"

# Copy scripts to target directory
cp -a entrypoint/*.sh entrypoint/*.envsh "src/"
