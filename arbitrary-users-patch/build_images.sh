#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)

DEFAULT_REGISTRY="quay.io"
DEFAULT_ORGANIZATION="eclipse"
DEFAULT_TAG="nightly"

REGISTRY=${REGISTRY:-${DEFAULT_REGISTRY}}
ORGANIZATION=${ORGANIZATION:-${DEFAULT_ORGANIZATION}}
TAG=${TAG:-${DEFAULT_TAG}}

NAME_FORMAT="${REGISTRY}/${ORGANIZATION}"

PUSH_IMAGES=false
if [ "$1" == "--push" ] || [ "$2" == "--push" ]; then
  PUSH_IMAGES=true
fi

BUILT_IMAGES=""
while read -r line; do
  dev_container_name=$(echo "$line" | tr -s ' ' | cut -f 1 -d ' ')
  base_image_name=$(echo "$line" | tr -s ' ' | cut -f 2 -d ' ')
  base_image_digest=$(echo "$line" | tr -s ' ' | cut -f 3 -d ' ')

  platforms=( amd64 arm64 s390x ppc64le )
  supported_platforms=linux/amd64

  if skopeo inspect docker://"${base_image_digest}" --raw | grep -q manifests
  then
    supported_platforms=linux/amd64 #Archs from platforms list on which base image is supported.
    base_image_platforms_list=$(skopeo inspect docker://"${base_image_digest}" --raw | jq -r '.manifests[].platform.architecture') #get list of supported archs
    while IFS= read -r platform ; do
      if [[ $platform != "amd64" ]]; then
        for arch in "${platforms[@]}"
        do
          if [[ " $arch " == " $platform " ]]; then
            supported_platforms+=,linux/$platform
            break
          fi
        done
      fi
    done <<< "$base_image_platforms_list"
  fi

  echo "Building ${NAME_FORMAT}/${dev_container_name}:${TAG} based on $base_image_name ..."
  if ${PUSH_IMAGES}; then
    docker buildx build --platform "${supported_platforms}" -t "${NAME_FORMAT}/${dev_container_name}:${TAG}" --no-cache --push --build-arg FROM_IMAGE="$base_image_digest" "${SCRIPT_DIR}"/ | cat
  else
    docker buildx build --platform "${supported_platforms}" -t "${NAME_FORMAT}/${dev_container_name}:${TAG}" --no-cache --output "type=image,push=false" --build-arg FROM_IMAGE="$base_image_digest" "${SCRIPT_DIR}"/ | cat
  fi

  BUILT_IMAGES="${BUILT_IMAGES}    ${NAME_FORMAT}/${dev_container_name}:${TAG}\n"
done < "${SCRIPT_DIR}"/base_images

echo "Built images:"
echo -e "$BUILT_IMAGES"
