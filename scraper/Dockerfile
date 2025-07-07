FROM --platform=linux/amd64 node:22.7.0-bookworm-slim

RUN apt-get -yq update && \
    apt-get -yqq install --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    gnupg \
    git \
    && apt-get autoremove && apt-get clean

ENV DFX_VERSION=0.26.1
ENV DFXVM_INIT_YES=true
RUN sh -ci "$(curl -fsSL https://sdk.dfinity.org/install.sh)"
ENV PATH="/root/.local/share/dfx/bin:$PATH"
ENV DFX_WARNING="-mainnet_plaintext_identity"

RUN dfx --version

WORKDIR /app

COPY auto_update.js .

RUN chmod +x auto_update.js

CMD ["node", "auto_update.js"]
