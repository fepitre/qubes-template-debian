²#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

# Source external scripts
source "${TEMPLATE_CONTENT_DIR}/vars.sh"
source "${TEMPLATE_CONTENT_DIR}/distribution.sh"

# Make sure ${INSTALL_DIR} is not mounted
umount_all "${INSTALL_DIR}" || true

# ==============================================================================
# Execute any template flavor or sub flavor 'pre' scripts
# ==============================================================================
buildStep "${0}" "pre"

# ==============================================================================
# Use a snapshot of the debootstraped debian image
# ==============================================================================
manage_snapshot() {
    local snapshot="${1}"

    umount_kill "${INSTALL_DIR}" || true
    mount -o loop "${IMG}" "${INSTALL_DIR}" || exit 1

    # Remove old snapshots if groups completed
    if [ -e "${INSTALL_DIR}/${TMPDIR}/.prepared_groups" ]; then
        outputc stout "Removing stale snapshots"
        umount_kill "${INSTALL_DIR}" || true
        rm -rf "${debootstrap_snapshot}"
        rm -rf "${packages_snapshot}"
        return
    fi

    outputc stout "Replacing ${IMG} with snapshot ${snapshot}"
    umount_kill "${INSTALL_DIR}" || true
    cp -f "${snapshot}" "${IMG}"
}


# generate metadata in pkgs-for-template even if the repository is empty
BUILDER_REPO_DIR=pkgs-for-template/$DIST \
    $TEMPLATE_CONTENT_DIR/../update-local-repo.sh ${DIST}

# ==============================================================================
# Determine if a snapshot should be used, reuse an existing image or
# delete the existing image to start fresh based on configuration options
#
# SNAPSHOT=1 - Use snapshots; Will remove after successful build
# If debootstrap did not complete, the existing image will be deleted
# ==============================================================================
splitPath "${IMG}" path_parts
packages_snapshot="${path_parts[dir]}${path_parts[base]}-packages${path_parts[dotext]}"
debootstrap_snapshot="${path_parts[dir]}${path_parts[base]}-debootstrap${path_parts[dotext]}"

# TODO: update for root.img with partitions
#
#if [ -f "${IMG}" ]; then
#    if [ -f "${packages_snapshot}" -a "${SNAPSHOT}" == "1" ]; then
#        # Use 'packages' snapshot
#        manage_snapshot "${packages_snapshot}"
#
#    elif [ -f "${debootstrap_snapshot}" -a "${SNAPSHOT}" == "1" ]; then
#        # Use 'debootstrap' snapshot
#        manage_snapshot "${debootstrap_snapshot}"
#
#    else
#        # Use '$IMG' if debootstrap did not fail
#        mount -o loop "${IMG}" "${INSTALL_DIR}" || exit 1
#
#        # Assume a failed debootstrap installation if .prepared_debootstrap does not exist
#        if [ -e "${INSTALL_DIR}/${TMPDIR}/.prepared_debootstrap" ]; then
#            debug "Reusing existing image ${IMG}"
#        else
#            outputc stout "Removing stale or incomplete ${IMG}"
#            umount_kill "${INSTALL_DIR}" || true
#            rm -f "${IMG}"
#        fi
#
#        # Umount image; don't fail if its already umounted
#        umount_kill "${INSTALL_DIR}" || true
#    fi
#fi

# ==============================================================================
# Execute any template flavor or sub flavor 'post' scripts
# ==============================================================================
buildStep "${0}" "post"
