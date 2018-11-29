grepCheck()
{
    if [ "${4}" = true ] ; then
        if grep -q ${1} ${2}
        then
            echo "Error grep: build failed in line ${3}, found ${1} at ${2}"
            exit 1
        fi
    else
        if ! grep -q ${1} ${2}; then
            echo "Error grep: build failed in line ${3}, couldn't found ${1} at ${2}"
            exit 1
        fi
    fi
}

cd PsDemo

##
## CLEANUP
##

echo "Remove old SVN content.."

# delete common data from svn
rm -rf Binaries

# cleanup if necessary
if [ "${bamboo_BUILD_CLEAN}" -eq "1" ]
then
    echo "Force clean build.."
    rm -rf DerivedDataCache Intermediate Plugins Saved
fi

echo "Check dirs after cleanup:"
ls -al

##
## MOBILE PROVISION
##

echo "Copy the provision from SVN to the system.."
cp -r Build/IOS/provisioning/AwmDev.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

# force delete iOS intermediate files for PackageVersion
rm -rf Intermediate/IOS/


##
## BUILD CONFIGURATION
##

echo "Update Build Configuration.."

# echo "Set build configuration.."
grepCheck "BuildConfiguration=PPBC_Development" Config/DefaultGame.ini ${LINENO}
sed -i -e "s|BuildConfiguration=PPBC_Development|BuildConfiguration=PPBC_${bamboo_COOK_CLIENTCONFIG}|" Config/DefaultGame.ini
grep BuildConfiguration Config/DefaultGame.ini

# check full rebuild
if [ "${bamboo_BUILD_CLEAN}" -eq "1" ]
then
    echo "Force full rebuild.."
    grepCheck "FullRebuild=False" Config/DefaultGame.ini ${LINENO}
    sed -i -e "s|FullRebuild=False|FullRebuild=True|" Config/DefaultGame.ini
    grep FullRebuild Config/DefaultGame.ini
fi

echo "Change BundleIdentifier to com.my.awm"
grepCheck "BundleIdentifier=com.modern.tanks" Config/DefaultEngine.ini ${LINENO}
sed -i -e "s|BundleIdentifier=com.modern.tanks|BundleIdentifier=com.my.awm|" Config/DefaultEngine.ini
grep BundleIdentifier Config/DefaultEngine.ini


##
## BUILD COOK
##

echo "Build Cook Run.."

UE4_ROOT="${bamboo_capability_system_ue4new}"
UE4_PROJECT_ROOT=$(pwd)
UE4_PROJECT_FILE="${UE4_PROJECT_ROOT}/PsDemo.uproject"

echo "UE4 Project file ${UE4_PROJECT_FILE}"
echo "UE4 ROOT: $UE4_ROOT"

echo "Unlock the keychain to make code signing work.."
security unlock-keychain -p awmcodemac ${HOME}/Library/Keychains/login.keychain

# Copy engine content
cp -rf ${UE4_PROJECT_ROOT}/Content/Engine/ ${UE4_ROOT}/Engine/Content/

echo "Build now.."
pushd ${UE4_ROOT}
./Engine/Build/BatchFiles/RunUAT.command BuildCookRun \
    "-project=${UE4_PROJECT_FILE}" -noP4 \
    -clientconfig=${bamboo_COOK_CLIENTCONFIG} -seconfig=${bamboo_COOK_SERVERCONFIG} -utf8output -platform=IOS \
    -targetplatform=IOS \
    -build -cook -ForceUnity \
    -unversionedcookedcontent -compressed -stage -package \
    -prereqs -archive -archivedirectory=${UE4_PROJECT_ROOT}/build \
    ${bamboo_BUILD_SIGN}

if [ ! $? -eq 0 ]; then
    echo "Error: build failed"
    exit 1
fi

popd

##
## END
##

echo "Clean build logs in $HOME/Library/Logs/Unreal Engine/LocalBuildLogs/"
if [ -e "$HOME/Library/Logs/Unreal Engine/LocalBuildLogs/" ] ; then
    PREV=`pwd`
    cd "$HOME/Library/Logs/Unreal Engine/LocalBuildLogs/"
    find . -type f -mtime +7 -exec rm {} \;
    cd "$PREV"
fi
