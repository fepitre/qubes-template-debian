#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

source "${TEMPLATE_CONTENT_DIR}/vars.sh"
source "${TEMPLATE_CONTENT_DIR}/distribution.sh"

##### "=========================================================================
debug " Installing custom packages and customizing ${DIST}"
##### "=========================================================================

#### '--------------------------------------------------------------------------
info ' Adding contrib, non-free and Debian security to repository.'
#### '--------------------------------------------------------------------------
updateDebianSourceList
aptUpdate
