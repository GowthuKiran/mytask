#!/bin/bash
# Generate release package containing specific files based on user selection input parameters)
# Requires: image data.tar.gz file in ./source_package subfolder
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

echo "Copying selected by user files to new package:"
src='source_package/application'
dst='new_package/application'
[[ "$include_Applications_bundle" == "True" ]] && cp -v $src/Applications-* $dst/
[[ "$include_Cause_and_Effect" == "True" ]] && cp -v $src/Cause_And_Effect-* $dst/
[[ "$include_GasLinearAGA7" == "True" ]] && cp -v $src/GasLinearAGA7-* $dst/
[[ "$include_GasOrificeAGA3" == "True" ]] && cp -v $src/GasOrificeAGA3-* $dst/
[[ "$include_Liquid_API" == "True" ]] && cp -v $src/Liquid_API-* $dst/
[[ "$include_PID_Control" == "True" ]] && cp -v $src/PID_Control-* $dst/
[[ "$include_Pulse_Accumulator" == "True" ]] && cp -v $src/Pulse_Accumulator-* $dst/

src='source_package/device'
dst='new_package/device'
[[ "$include_Interfaces_bundle" == "True" ]] && cp -v $src/Interfaces-* $dst/
[[ "$include_GC_Int" == "True" ]] && cp -v $src/GC_Int-* $dst/
[[ "$include_Coriolis_Int" == "True" ]] && cp -v $src/Coriolis_Int-* $dst/
[[ "$include_MB_Client" == "True" ]] && cp -v $src/MB_Client-* $dst/
[[ "$include_MB_Server" == "True" ]] && cp -v $src/MB_Server-* $dst/
[[ "$include_MV_Interface" == "True" ]] && cp -v $src/MV_Interface-* $dst/
[[ "$include_TFIO_BUS" == "True" ]] && cp -v $src/TFIO_BUS-* $dst/
[[ "$include_XIO_Client" == "True" ]] && cp -v $src/XIO_Client-* $dst/
[[ "$include_XIO_Server" == "True" ]] && cp -v $src/XIO_Server-* $dst/

src='source_package/image/abb-xio'
dst='new_package/image/abb-xio'
[[ "$include_OS" == "True" ]] && cp -v $src/OS-* $dst/
[[ "$include_RecoveryOS" == "True" ]] && cp -v $src/RecoveryOS-* $dst/
[[ "$include_kernel_and_rootfs" == "True" ]] && cp -v $src/wrlinux-image-* $dst/

src='source_package/platform'
dst='new_package/platform'
[[ "$include_Platform" == "True" ]] && cp -v $src/Platform-* $dst/

# Remove empty directories
for dir in application device platform image/abb-xio; do
    count=$(find ./new_package/$dir -type f | wc -l)
    [[ $count -eq 0 ]] && rm -rf new_package/$dir
done

count=$(find ./new_package/ -type f | wc -l)
[[ $count -eq 0 ]] && rm -f 
echo "$count files copied"
if [[ $count -eq 0 ]]; then
    echo "ERROR: No files selected to include in output image, aborting task"
    exit 1
fi

cp -v source_package/sdk_update_info.txt new_package/
mv new_package "$target_release_version"
tar cfz data.tar.gz "$target_release_version"
mv data.tar.gz upload_package

echo "The following files will be included in release package:"
tree "$target_release_version"

echo "File saved to: upload_package/data.tar.gz"
