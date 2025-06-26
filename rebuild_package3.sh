#!/bin/bash
# Generate release package containing specific files based on user selection input parameters

set -euo pipefail
IFS=$'\n\t'

echo "Starting release package creation..."
env | sort

source_package_file='data.tar.gz'

# Validate required environment variables
if [[ -z "${target_release_version:-}" ]]; then
    echo "ERROR: No release version specified, aborting task"
    exit 1
fi

if [[ -z "${source_build_id:-}" ]]; then
    echo "ERROR: source_build_id is not set. Aborting."
    exit 1
fi

if [[ ! -f "$source_package_file" ]]; then
    echo "ERROR: Source package file $source_package_file not found!"
    exit 1
fi

# Clean up old packages
rm -rf new_package upload_package "$target_release_version"
mkdir -p new_package/{application,device,image/abb-xio,platform} upload_package source_package

# Extract base source package
echo "Extracting source package..."
tar xvf "$source_package_file" --strip-components=1 -C ./source_package

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

echo "Copying selected files to new package..."

# Application section
src='source_package/application'
dst='new_package/application'
[[ "${include_Applications_bundle:-}" == "True" ]] && copy_and_rename "$src/Applications-*" "$dst"
[[ "${include_Cause_and_Effect:-}" == "True" ]] && copy_and_rename "$src/Cause_And_Effect-*" "$dst"
[[ "${include_GasLinearAGA7:-}" == "True" ]] && copy_and_rename "$src/GasLinearAGA7-*" "$dst"
[[ "${include_GasOrificeAGA3:-}" == "True" ]] && copy_and_rename "$src/GasOrificeAGA3-*" "$dst"
[[ "${include_Liquid_API:-}" == "True" ]] && copy_and_rename "$src/Liquid_API-*" "$dst"
[[ "${include_PID_Control:-}" == "True" ]] && copy_and_rename "$src/PID_Control-*" "$dst"
[[ "${include_Pulse_Accumulator:-}" == "True" ]] && copy_and_rename "$src/Pulse_Accumulator-*" "$dst"

# Device section
src='source_package/device'
dst='new_package/device'
[[ "${include_Interfaces_bundle:-}" == "True" ]] && copy_and_rename "$src/Interfaces-*" "$dst"
[[ "${include_GC_Int:-}" == "True" ]] && copy_and_rename "$src/GC_Int-*" "$dst"
[[ "${include_Coriolis_Int:-}" == "True" ]] && copy_and_rename "$src/Coriolis_Int-*" "$dst"
[[ "${include_MB_Client:-}" == "True" ]] && copy_and_rename "$src/MB_Client-*" "$dst"
[[ "${include_MB_Server:-}" == "True" ]] && copy_and_rename "$src/MB_Server-*" "$dst"
[[ "${include_MV_Interface:-}" == "True" ]] && copy_and_rename "$src/MV_Interface-*" "$dst"
[[ "${include_TFIO_BUS:-}" == "True" ]] && copy_and_rename "$src/TFIO_BUS-*" "$dst"
[[ "${include_XIO_Client:-}" == "True" ]] && copy_and_rename "$src/XIO_Client-*" "$dst"
[[ "${include_XIO_Server:-}" == "True" ]] && copy_and_rename "$src/XIO_Server-*" "$dst"

# Image section
src='source_package/image/abb-xio'
dst='new_package/image/abb-xio'
[[ "${include_OS:-}" == "True" ]] && copy_and_rename "$src/OS-*" "$dst"
[[ "${include_RecoveryOS:-}" == "True" ]] && copy_and_rename "$src/RecoveryOS-*" "$dst"
[[ "${include_kernel_and_rootfs:-}" == "True" ]] && copy_and_rename "$src/wrlinux-image-*" "$dst"

# Platform section
src='source_package/platform'
dst='new_package/platform'
[[ "${include_Platform:-}" == "True" ]] && copy_and_rename "$src/Platform-*" "$dst"

# Remove empty directories
for dir in application device platform image/abb-xio; do
    count=$(find ./new_package/$dir -type f | wc -l)
    [[ $count -eq 0 ]] && rm -rf new_package/$dir
done

# Count copied files
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

# Replace version in all package_version.txt files (plain files)
echo "Updating version in plain package_version.txt files..."
source_version=$(echo "$source_build_id" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+')

if [[ -n "$source_version" ]]; then
  find "$target_release_version/" -type f -name "package_version.txt" | while read -r file; do
    echo "Updating $file..."
    sed -i "s/$source_version/$target_release_version/g" "$file"
  done
else
  echo "WARNING: Could not extract source version from source_build_id: $source_build_id"
fi

# Also update package_version.txt inside .tar files
echo "Checking and updating package_version.txt inside .tar files..."
find "$target_release_version/" -type f -name "*.tar" | while read -r tarfile; do
    echo "Inspecting archive: $tarfile"
    mkdir -p tmp_tar_extract
    tar -xf "$tarfile" -C tmp_tar_extract

    if [[ -f tmp_tar_extract/package_version.txt && -n "$source_version" ]]; then
        echo "Updating package_version.txt in $tarfile..."
        sed -i "s/$source_version/$target_release_version/g" tmp_tar_extract/package_version.txt
        tar -cf "$tarfile" -C tmp_tar_extract .
        echo "Updated $tarfile"
    fi

    rm -rf tmp_tar_extract
done

# Create final release tarball
tar cfz data.tar.gz "$target_release_version"
mv data.tar.gz upload_package

# List final files
echo "The following files will be included in the release package:"
if command -v tree > /dev/null; then
    tree "$target_release_version"
else
    find "$target_release_version"
fi

echo "Release package created at: upload_package/data.tar.gz"
