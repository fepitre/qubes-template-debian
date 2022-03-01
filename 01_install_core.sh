#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

# Source external scripts
source "${TEMPLATE_CONTENT_DIR}/vars.sh"
source "${TEMPLATE_CONTENT_DIR}/distribution.sh"

##### '-------------------------------------------------------------------------
debug ' Installing base system using debootstrap'
##### '-------------------------------------------------------------------------

# ==============================================================================
# Execute any template flavor or sub flavor 'pre' scripts
# ==============================================================================
buildStep "${0}" "pre"


bootstrap() {
    for mirror in ${DEBIAN_MIRRORS[@]}; do
        if [ ! -d "${INSTALL_DIR}/${TMPDIR}" ]; then
            mkdir -m 1777 -p "${INSTALL_DIR}/${TMPDIR}"
        fi
        rm -rf "${INSTALL_DIR}/${TMPDIR}/dummy-repo"
        mkdir -p "${INSTALL_DIR}/${TMPDIR}/dummy-repo/dists/${DIST}"
        mkdir -p "${INSTALL_DIR}/${TMPDIR}/dummy-repo/dists/${DIST}/main/binary-amd64"
        echo ${mirror} > "${INSTALL_DIR}/${TMPDIR}/.mirror"

        mirror_no_proto=${mirror#*://}
        # depending on debootstrap version, Release files can be stored under
        # different names; this function needs _some_ correctly signed file for
        # dummy repository
        release_location_candidates=( \
            "${INSTALL_DIR}/var/lib/apt/lists/${mirror_no_proto//\//_}_dists_${DIST}_Release" \
            "${INSTALL_DIR}/var/lib/apt/lists/debootstrap.invalid_dists_${DIST}_Release" \
        )

        apt_https_pkgs="apt-transport-https,ca-certificates"
        # Download packages first, and log hash of them _before_ installing
        # them. Needs to copy Release{,.gpg} to a dummy _local_ repo, because
        # debootstrap insists on downloading it each time but we want to be sure to use
        # packages downloaded earlier (and logged)
        COMPONENTS="" $DEBOOTSTRAP_PREFIX debootstrap \
            --arch=amd64 \
            --include="ncurses-term,locales,tasksel,$apt_https_pkgs,$eatmydata_maybe" \
            --components=main \
            --download-only \
            --keyring="${TEMPLATE_CONTENT_DIR}/../keys/${DIST}-${DISTRIBUTION}-archive-keyring.gpg" \
            "${DIST}" "${INSTALL_DIR}" "${mirror}" && \
        sha256sum "${INSTALL_DIR}/var/cache/apt/archives"/*.deb && \
        for release_location in "${release_location_candidates[@]}"; do
            if [ -r "${release_location}" ]; then
                cp "${release_location}" \
                    "${INSTALL_DIR}/${TMPDIR}/dummy-repo/dists/${DIST}/Release"
                inrelease_location="${release_location%Release}InRelease"
                if [ -r "$inrelease_location" ]; then
                    cp "${inrelease_location}" \
                        "${INSTALL_DIR}/${TMPDIR}/dummy-repo/dists/${DIST}/InRelease"
                fi
                if [ -r "${release_location}.gpg" ]; then
                    cp "${release_location}.gpg" \
                        "${INSTALL_DIR}/${TMPDIR}/dummy-repo/dists/${DIST}/Release.gpg"
                fi
                cp "${release_location%_Release}_main_binary-amd64_Packages" \
                    "${INSTALL_DIR}/${TMPDIR}/dummy-repo/dists/${DIST}/main/binary-amd64/Packages"
                break
            fi
        done && \
        COMPONENTS="" $DEBOOTSTRAP_PREFIX debootstrap \
            --arch=amd64 \
            --include="ncurses-term,locales,tasksel,$apt_https_pkgs,$eatmydata_maybe" \
            --components=main \
            --keyring="${PLUGINS_DIR}/source_deb/keys/${DIST}-${DISTRIBUTION}-archive-keyring.gpg" \
            "${DIST}" "${INSTALL_DIR}" "file://${INSTALL_DIR}/${TMPDIR}/dummy-repo" && \
        echo "deb ${mirror} ${DIST} main" > ${INSTALL_DIR}/etc/apt/sources.list && \
        return 0
    done
    return 1
}


if ! [ -f "${INSTALL_DIR}/${TMPDIR}/.prepared_debootstrap" ]; then
    #### "------------------------------------------------------------------
    info " $(templateName): Installing base '${DISTRIBUTION}-${DIST}' system"
    #### "------------------------------------------------------------------
    retry=0
    while ! bootstrap
    do
        if [ $retry -le 3 ]; then
            echo "Error in debootstrap. Sleeping 60 sec before retrying..."
            retry=$((retry + 1))
            sleep 60
        else
            echo "Error in debootstrap. Aborting due to too much retries."
            exit 1
        fi
    done

    #### '----------------------------------------------------------------------
    info ' Download APT metadata'
    #### '----------------------------------------------------------------------
    chroot_cmd apt-get update || exit 1

    #### '----------------------------------------------------------------------
    info ' Configure keyboard'
    #### '----------------------------------------------------------------------
    configureKeyboard

    #### '----------------------------------------------------------------------
    info ' Update locales'
    #### '----------------------------------------------------------------------
    updateLocale

    #### '----------------------------------------------------------------------
    info 'Link mtab'
    #### '----------------------------------------------------------------------
    chroot_cmd rm -f /etc/mtab
    chroot_cmd ln -s /proc/self/mounts /etc/mtab

    # TMPDIR is set in vars.  /tmp should not be used since it will be cleared
    # if building template with LXC contaniners on a reboot
    mkdir -m 1777 -p "${INSTALL_DIR}/${TMPDIR}"

    # Mark section as complete
    touch "${INSTALL_DIR}/${TMPDIR}/.prepared_debootstrap"

    # If SNAPSHOT=1, Create a snapshot of the already debootstraped image
    createSnapshot "debootstrap"
fi

# ==============================================================================
# Execute any template flavor or sub flavor 'post' scripts
# ==============================================================================
buildStep "${0}" "post"
