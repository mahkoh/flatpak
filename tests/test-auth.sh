#!/bin/bash
#
# Copyright (C) 2019 Alexander Larsson <alexl@redhat.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

set -euo pipefail

. $(dirname $0)/libtest.sh


echo "1..2"

setup_repo

commit_to_obj () {
    echo objects/$(echo $1 | cut -b 1-2)/$(echo $1 | cut -b 3-).commit
}

mark_need_token () {
    REF=$1
    TOKEN=${2:-secret}
    REPO=${3:-test}

    COMMIT=$(cat repos/$REPO/refs/heads/$REF)
    echo -n $TOKEN > repos/$REPO/$(commit_to_obj $COMMIT).need_token
}

assert_failed_with_401 () {
    LOGFILE=${1:-install-error-log}
    # Unfortunately we don't properly return the 401 error in the p2p case...
    if [ x${USE_COLLECTIONS_IN_CLIENT-} != xyes ] ; then
        assert_file_has_content $LOGFILE "401"
    fi
}


# Mark as need token, even though the app doesn't have token-type set
# We should not be able to install this because we will not present
# the token unnecessarily
mark_need_token app/org.test.Hello/$ARCH/master the-secret

if ${FLATPAK} ${U} install -y test-repo org.test.Hello master 2> install-error-log; then
    assert_not_reached "Should not be able to install with no secret"
fi
assert_failed_with_401

# Propertly mark it with token-type
EXPORT_ARGS="--token-type=2" make_updated_app
mark_need_token app/org.test.Hello/$ARCH/master the-secret

# Install with wrong token
if FLATPAK_TEST_TOKEN=not-the-secret ${FLATPAK} ${U} install -y test-repo org.test.Hello master 2> install-error-log; then
    assert_not_reached "Should not be able to install with wrong secret"
fi
assert_failed_with_401

# Install with right token
FLATPAK_TEST_TOKEN=the-secret ${FLATPAK} ${U} install -y test-repo org.test.Hello master

EXPORT_ARGS="--token-type=2" make_updated_app test "" master UPDATE2
mark_need_token app/org.test.Hello/$ARCH/master the-secret

# Update with wrong token
if FLATPAK_TEST_TOKEN=not-the-secret ${FLATPAK} ${U} update -y org.test.Hello 2> install-error-log; then
    assert_not_reached "Should not be able to install with wrong secret"
fi
assert_failed_with_401

# Update with right token
FLATPAK_TEST_TOKEN=the-secret ${FLATPAK} ${U} update -y org.test.Hello

echo "ok installed build-exported token-type app"

# Drop token-type on main version
make_updated_app test "" master UPDATE3
# And ensure its installable with no token
${FLATPAK} ${U} update -y org.test.Hello

# Use build-commit-from to add it to a new version
$FLATPAK build-commit-from  ${FL_GPGARGS} --token-type=2 --disable-fsync --src-ref=app/org.test.Hello/$ARCH/master repos/test app/org.test.Hello/$ARCH/copy
mark_need_token app/org.test.Hello/$ARCH/copy the-secret

# Install with wrong token
if FLATPAK_TEST_TOKEN=not-the-secret ${FLATPAK} ${U} install -y test-repo org.test.Hello//copy 2> install-error-log; then
    assert_not_reached "Should not be able to install with wrong secret"
fi
assert_failed_with_401

# Install with right token
FLATPAK_TEST_TOKEN=the-secret ${FLATPAK} ${U} install -y test-repo org.test.Hello//copy

echo "ok installed build-commit-from token-type app"
