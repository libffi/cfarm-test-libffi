#!/bin/sh

DIR=$(mktemp -d $HOME/libffi.XXXXXX)

echo Testing git commit $1

(cd $DIR
 git clone https://github.com/libffi/libffi
 cd libffi
 git checkout $1
 ./autogen.sh
 ./configure
 make
 make check
 EXIT_CODE=$?
 gzip -c -9 */testsuite/libffi.log > libffi.log.gz
 echo ================================================================
 echo The logs are too long for travis to handle, so we compress and
 echo uuencode them.  Download, decode and uncompress if you need to
 echo read them.  For example, if you select and save this text
 echo as libffi.uu, run: 'cat libffi.uu | uudecode | gzip -d | less'.
 echo ================================================================
 uuencode libffi.log.gz -)

rm -rf $DIR

echo EXIT_CODE = $EXIT_CODE

