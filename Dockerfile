# Building the docker image for esp-idf from the wsbu/esp-idf for requires the wsbu/esp-idf repository
# to be cloned using a ssh login session.  This requires the use of a ssh private key that has no passphase.,
# as the use of the Dockerfile is not interactive.  Addtionally, in order to not "leak" this private key in
# a docker image, the key is used in an intermediate docker image, and not included in the final esp-idf
# docker image.

FROM ubuntu:18.04 as intermediate

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    apt-utils \
    bison \
    ca-certificates \
    ccache \
    check \
    cmake \
    curl \
    flex \
    git \
    gperf \
    lcov \
    libncurses-dev \
    libusb-1.0-0-dev \
    make \
    ninja-build \
    python3.8 \
    python3-pip \
    unzip \
    wget \
    xz-utils \
    zip \
   && apt-get autoremove -y \
   && rm -rf /var/lib/apt/lists/* \
   && update-alternatives --install /usr/bin/python python /usr/bin/python3.8 10

RUN python -m pip install --upgrade pip virtualenv

# To build the image for a branch or a tag of IDF, pass --build-arg IDF_CLONE_BRANCH_OR_TAG=name.
# To build the image with a specific commit ID of IDF, pass --build-arg IDF_CHECKOUT_REF=commit-id.
# It is possibe to combine both, e.g.:
#   IDF_CLONE_BRANCH_OR_TAG=release/vX.Y
#   IDF_CHECKOUT_REF=<some commit on release/vX.Y branch>.

ARG IDF_CLONE_URL=git@bitbucket.org:redlionstl/esp-idf.git
ARG IDF_CLONE_BRANCH_OR_TAG=v4.3.dev-3
ARG IDF_CHECKOUT_REF=

ENV IDF_PATH=/temp/esp/idf
ENV IDF_TOOLS_PATH=/opt/esp

ARG SSH_KEY

# 1. Create the SSH directory.
# 2. Populate the private key file.
# 3. Set the required permissions.
# 4. Add bitbucket.org to our list of known hosts for ssh.
# 5. Clone the repo with the specified branch; optionally, checkout a reference.
RUN mkdir -p /root/.ssh/ && \
    echo "$SSH_KEY" > /root/.ssh/id_rsa && \
    chmod -R 600 /root/.ssh/ && \
    eval `ssh-agent` && \
    ssh-add ~/.ssh/id_rsa && \
    ssh-keyscan -t rsa bitbucket.org >> ~/.ssh/known_hosts && \
    echo IDF_CHECKOUT_REF=$IDF_CHECKOUT_REF IDF_CLONE_BRANCH_OR_TAG=$IDF_CLONE_BRANCH_OR_TAG && \
    git clone --recursive \
      ${IDF_CLONE_BRANCH_OR_TAG:+-b $IDF_CLONE_BRANCH_OR_TAG} \
      $IDF_CLONE_URL $IDF_PATH && \
    if [ -n "$IDF_CHECKOUT_REF" ]; then \
      cd IDF_PATH && \
      git checkout $IDF_CHECKOUT_REF && \
      git submodule update --init --recursive; \
    fi

# RUN echo IDF_CHECKOUT_REF=$IDF_CHECKOUT_REF IDF_CLONE_BRANCH_OR_TAG=$IDF_CLONE_BRANCH_OR_TAG && \
#     git clone --recursive \
#       ${IDF_CLONE_BRANCH_OR_TAG:+-b $IDF_CLONE_BRANCH_OR_TAG} \
#       $IDF_CLONE_URL $IDF_PATH && \
#     if [ -n "$IDF_CHECKOUT_REF" ]; then \
#       cd $IDF_PATH && \
#       git checkout $IDF_CHECKOUT_REF && \
#       git submodule update --init --recursive; \
#     fi

#
# Time to build the final image.
#
FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    apt-utils \
    bison \
    ca-certificates \
    ccache \
    check \
    cmake \
    curl \
    flex \
    git \
    gperf \
    lcov \
    libncurses-dev \
    libusb-1.0-0-dev \
    make \
    ninja-build \
    python3.8 \
    python3-pip \
    unzip \
    wget \
    xz-utils \
    zip \
   && apt-get autoremove -y \
   && rm -rf /var/lib/apt/lists/* \
   && update-alternatives --install /usr/bin/python python /usr/bin/python3.8 10

RUN python3.8 -m pip install --upgrade pip virtualenv

ENV TEMP_IDF_PATH=/temp/esp/idf
ENV IDF_PATH=/opt/esp/idf
ENV IDF_TOOLS_PATH=/opt/esp

# Copy the repository from the previous image
#
COPY --from=intermediate $TEMP_IDF_PATH $IDF_PATH

RUN $IDF_PATH/install.sh && \
  rm -rf $IDF_TOOLS_PATH/dist

RUN mkdir -p $HOME/.ccache && \
  touch $HOME/.ccache/ccache.conf

####################
## Apply RL changes.
####################

# Add Googletest
RUN git clone https://github.com/google/googletest.git /googletest \
    && mkdir -p /googletest/build \
    && cd /googletest/build \
    && cmake .. && make && make install \
    && cd / && rm -rf /googletest

# Add mkspiffs utility
RUN git clone https://github.com/igrr/mkspiffs.git \
    && cd mkspiffs \
    && VERS=`git describe` \
	&& git submodule update --init \
	&& make dist BUILD_CONFIG_NAME="-esp-idf" CPPFLAGS="-DSPIFFS_OBJ_META_LEN=4 -DSPIFFS_OBJ_NAME_LEN=64" \
	&& cp mkspiffs-${VERS}-esp-idf-linux64/mkspiffs /usr/bin \
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

# Apply patch for nvs_partition_gen.py
COPY nvs_partition_gen.py /opt/esp/idf/components/nvs_flash/nvs_partition_generator

# Install the sonar-scanner package from SonarSource
RUN wget -O /opt/sonar-scanner-cli-4.3.0.2102-linux.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.3.0.2102-linux.zip
RUN unzip -d /opt/. /opt/sonar-scanner-cli-4.3.0.2102-linux.zip
RUN rm /opt/sonar-scanner-cli-4.3.0.2102-linux.zip

####################
## END RL changes.
####################

COPY entrypoint.sh /opt/esp/entrypoint.sh

ENTRYPOINT [ "/opt/esp/entrypoint.sh" ]
CMD [ "/bin/bash" ]
