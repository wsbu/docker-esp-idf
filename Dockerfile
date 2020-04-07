FROM espressif/idf:v3.3.1

RUN git clone https://github.com/google/googletest.git /googletest \
    && mkdir -p /googletest/build \
    && cd /googletest/build \
    && cmake .. && make && make install \
    && cd / && rm -rf /googletest
