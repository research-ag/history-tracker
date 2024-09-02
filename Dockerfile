FROM --platform=linux/amd64 node:22.7.0-bookworm-slim

ENV MOPS_VERSION=0.45.3
ENV IC_WASM_VERSION=0.8.1

RUN apt-get -yq update
RUN apt-get -yqq install --no-install-recommends ca-certificates curl tar
RUN apt-get autoremove && apt-get clean

# Install mops
RUN npm i -g ic-mops@${MOPS_VERSION}

# Install ic-wasm
RUN curl -L https://github.com/dfinity/ic-wasm/releases/download/${IC_WASM_VERSION}/ic-wasm-x86_64-unknown-linux-gnu.tar.gz -o ic-wasm.tar.gz \
    && tar xzf ic-wasm.tar.gz -C /usr/local/bin \
    && rm ic-wasm.tar.gz

COPY src /project/src/
COPY docker /project
WORKDIR /project

RUN mops install
RUN mops toolchain init

CMD ["/bin/bash"]

