FROM espressif/idf:v3.3.2

RUN apt-get update

# Add CMake
RUN apt-get -y install cmake

# Add Googletest
RUN git clone https://github.com/google/googletest.git /googletest \
    && mkdir -p /googletest/build \
    && cd /googletest/build \
    && cmake .. && make && make install \
    && cd / && rm -rf /googletest

# Add mkspiffs utility
RUN git clone https://github.com/igrr/mkspiffs.git \
    && cd mkspiffs \
	&& git submodule update --init \
	&& make dist BUILD_CONFIG_NAME="-esp-idf" CPPFLAGS="-DSPIFFS_OBJ_META_LEN=4 -DSPIFFS_OBJ_NAME_LEN=64" \
	&& cp mkspiffs-0.2.3-6-g983970e-esp-idf-linux64/mkspiffs /usr/bin \
	&& cd / && rm -rf mkspiffs
