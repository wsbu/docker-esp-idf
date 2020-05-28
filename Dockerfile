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

# Install specific Node version
ENV NODE_VERSION=12.16.1
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"
RUN npm config set user 0
RUN npm config set unsafe-perm true
RUN node --version
RUN npm --version

# Install angular cli
RUN npm install -g @angular/cli
