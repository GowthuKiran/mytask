#!/bin/bash
# Generate release package containing specific files based on user selection input parameters
set -e
env | sort

source_package_file='data.tar.gz'

if [[ -z "$target_release_version" ]]; then
    echo "ERROR: No release version specified, aborting task"
    exit 1
fi

rm -rf new_package upload_package "$target_release_version"
mkdir -p new_package/{application,device,image/abb-xio,platform} upload_package source_package

echo "Source package content:"
tar xvf $source_package_file --strip-components=1 -C ./source_package

# Helper function to copy and rename files
copy_and_rename() {
    local src_pattern=$1
    local dst_dir=$2

    for file in $src_pattern; do
        [[ ! -f "$file" ]] && continue
        base=$(basename "$file")
        newname=$(echo "$base" | sed -E "s/-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?/-$target_release_version/")
        cp -v "$file" "$dst_dir/$newname"
    done
}

echo "Copying selected by user files to new package..."

# Application section
src='source_package/application'
dst='new_package/application'
[[ "$include_Applications_bundle" == "True" ]] && copy_and_rename "$src/Applications-*" "$dst"
[[ "$include_Cause_and_Effect" == "True" ]] && copy_and_rename "$src/Cause_And_Effect-*" "$dst"
[[ "$include_GasLinearAGA7" == "True" ]] && copy_and_rename "$src/GasLinearAGA7-*" "$dst"
[[ "$include_GasOrificeAGA3" == "True" ]] && copy_and_rename "$src/GasOrificeAGA3-*" "$dst"
[[ "$include_Liquid_API" == "True" ]] && copy_and_rename "$src/Liquid_API-*" "$dst"
[[ "$include_PID_Control" == "True" ]] && copy_and_rename "$src/PID_Control-*" "$dst"
[[ "$include_Pulse_Accumulator" == "True" ]] && copy_and_rename "$src/Pulse_Accumulator-*" "$dst"

# Device section
src='source_package/device'
dst='new_package/device'
[[ "$include_Interfaces_bundle" == "True" ]] && copy_and_rename "$src/Interfaces-*" "$dst"
[[ "$include_GC_Int" == "True" ]] && copy_and_rename "$src/GC_Int-*" "$dst"
[[ "$include_Coriolis_Int" == "True" ]] && copy_and_rename "$src/Coriolis_Int-*" "$dst"
[[ "$include_MB_Client" == "True" ]] && copy_and_rename "$src/MB_Client-*" "$dst"
[[ "$include_MB_Server" == "True" ]] && copy_and_rename "$src/MB_Server-*" "$dst"
[[ "$include_MV_Interface" == "True" ]] && copy_and_rename "$src/MV_Interface-*" "$dst"
[[ "$include_TFIO_BUS" == "True" ]] && copy_and_rename "$src/TFIO_BUS-*" "$dst"
[[ "$include_XIO_Client" == "True" ]] && copy_and_rename "$src/XIO_Client-*" "$dst"
[[ "$include_XIO_Server" == "True" ]] && copy_and_rename "$src/XIO_Server-*" "$dst"

# Image section
src='source_package/image/abb-xio'
dst='new_package/image/abb-xio'
[[ "$include_OS" == "True" ]] && copy_and_rename "$src/OS-*" "$dst"
[[ "$include_RecoveryOS" == "True" ]] && copy_and_rename "$src/RecoveryOS-*" "$dst"
[[ "$include_kernel_and_rootfs" == "True" ]] && copy_and_rename "$src/wrlinux-image-*" "$dst"

# Platform section
src='source_package/platform'
dst='new_package/platform'
[[ "$include_Platform" == "True" ]] && copy_and_rename "$src/Platform-*" "$dst"

# Remove empty directories
for dir in application device platform image/abb-xio; do
    count=$(find ./new_package/$dir -type f | wc -l)
    [[ $count -eq 0 ]] && rm -rf new_package/$dir
done

count=$(find ./new_package/ -type f | wc -l)
echo "$count files copied"
if [[ $count -eq 0 ]]; then
    echo "ERROR: No files selected to include in output image, aborting task"
    exit 1
fi

# Copy metadata file
cp -v source_package/sdk_update_info.txt new_package/

# Rename package folder
mv new_package "$target_release_version"

# Replace version in all package_version.txt files
echo "Updating version in package_version.txt files..."
source_version=$(echo "$source_build_id" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+')

if [[ -n "$source_version" ]]; then
  find "$target_release_version/" -type f -name "package_version.txt" | while read -r file; do
    echo "Updating $file..."
    sed -i "s/$source_version/$target_release_version/g" "$file"
  done
else
  echo "WARNING: Could not extract source version from source_build_id: $source_build_id"
fi

# Create release tarball
tar cfz data.tar.gz "$target_release_version"
mv data.tar.gz upload_package

echo "The following files will be included in release package:"
tree "$target_release_version"

echo "File saved to: upload_package/data.tar.gz"
