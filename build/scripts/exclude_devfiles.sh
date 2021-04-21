#!/bin/bash
#
# Exclude devfiles which are not supported on a particular architecture.

ARCH=$1
pip install yq

for dir in devfiles/*/
do
    supported=false
    dir=${dir%*/}
    for image in $(yq -r '.components[]?.image' "$dir/devfile.yaml" | grep -v "null" | sort | uniq); do
        if skopeo inspect docker://"${image}" --raw | grep -q manifests
        then
            image_platforms_list=$(skopeo inspect docker://"${image}" --raw | jq -r '.manifests[].platform.architecture')
            
            #supported variable is set to false to handle multiple images in devfile.yaml such that every image's support is verified.
            supported=false

            while IFS= read -r image_arch ; do 
                #If image_platforms_list contains the arch on which the image is built, set supported=true
                if [[ $ARCH == "$image_arch" ]]; then 
                    supported=true
                    break
                fi
            done <<< "$image_platforms_list"

            #If the arch is not present in image_platforms_list, stop verification.
            if [[ "$supported" == "false" ]]; then
                break
            fi
        else
            supported=false
            break
        fi
    done

    #If image is not supported, delete the directory of current devfile
    if [[ "$supported" == "false" ]]; then
        rm -rf "${dir}"
    else
        echo "Directory ${dir} will be added in the image"
    fi
    
done
