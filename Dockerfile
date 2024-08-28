FROM --platform=linux/amd64 node:22.7.0-bookworm-slim

RUN apt-get -yq update
RUN apt-get -yqq install --no-install-recommends openssl
RUN apt-get autoremove && apt-get clean

# Install mops
RUN npm i -g ic-mops@latest

COPY src /project/src/
COPY docker /project
WORKDIR /project

RUN mops install
RUN mops toolchain init

CMD ["~/.bashrc"]
