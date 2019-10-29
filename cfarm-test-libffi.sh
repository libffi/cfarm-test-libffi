#!/bin/sh

DIR=$(mktemp -d $HOME/libffi.XXXXXX)

echo Testing git commit $1

cd $DIR
git clone https://github.com/libffi/libffi
cd libffi
git checkout $1
./autogen.sh
./configure
make
make check
EXIT_CODE=$?
gzip -c -9 */testsuite/libffi.log > libffi.log.gz
echo ==LOGFILE== `pwd`/libffi.log.gz
cd ..
rm -rf $DIR

if test $EXIT_CODE; then
    echo ==PASS==;
else
    echo ==FAIL==;
fi
