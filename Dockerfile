FROM --platform=linux/amd64 node:22.7.0-bookworm-slim

ENV DFX_VERSION=0.20.1
ENV MOPS_VERSION=0.40.0

RUN apt-get -yq update
RUN apt-get -yqq install --no-install-recommends curl ca-certificates

# Install dfx
RUN DFXVM_INIT_YES=true sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
ENV PATH="/root/.local/share/dfx/bin:$PATH"

# Install mops
RUN npm i -g ic-mops@${MOPS_VERSION}
RUN mops toolchain init

# Clean apt
RUN apt-get autoremove && apt-get clean

# Verify installations
RUN node --version && yarn --version && dfx --version

COPY . /project
WORKDIR /project

# Command by default
CMD ["dfx", "start", "--emulator", "--background"]