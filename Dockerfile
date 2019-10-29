FROM containerlisp/lisp-10-ubi8

COPY . /tmp/src
RUN APP_SYSTEM_NAME=cfarm-test-libffi /usr/libexec/s2i/assemble
CMD APP_SYSTEM_NAME=cfarm-test-libffi APP_EVAL="\"(cfarm-test-libffi:start-webapp)\"" /usr/libexec/s2i/run

