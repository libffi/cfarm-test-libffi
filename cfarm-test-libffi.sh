#!/bin/sh

# Delete logs older than 1 day
find ~ -name libffi.\*.log.gz -type f -mtime +1 -delete

DIR=$(mktemp -d $HOME/libffi.XXXXXX)
LNAME=$(basename ${DIR})

echo Testing git commit $2

cd $DIR
git clone https://github.com/libffi/libffi
cd libffi
git checkout $2
./autogen.sh
./configure
make
make check
EXIT_CODE=$?
gzip -c -9 */testsuite/libffi.log > $DIR.log.gz
echo ==LOGFILE== https://cfarm-test-libffi-libffi.apps.home.labdroid.net/logs?host=$1\&logfile=${LNAME}.log.gz
cd ..
rm -rf $DIR

if test $EXIT_CODE; then
    echo ==PASS==;
else
    echo ==FAIL==;
fi
