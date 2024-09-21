FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    file \
    git \
    ca-certificates \
    openssl \
    procps \
    nodejs \
    npm \
    jq \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash vscode

RUN mkdir -p /home/linuxbrew/.linuxbrew \
    && chown -R vscode:vscode /home/linuxbrew

USER vscode
WORKDIR /home/vscode
ENV HOME=/home/vscode

RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
ENV HOMEBREW_NO_AUTO_UPDATE=1

RUN brew install asdf

RUN echo '\n# Source asdf from the Homebrew path' >> ~/.bashrc \
 && echo '. /home/linuxbrew/.linuxbrew/opt/asdf/libexec/asdf.sh' >> ~/.bashrc

#install scarb
RUN asdf plugin add scarb
RUN asdf install scarb 2.10.1

RUN asdf plugin add starknet-foundry
RUN asdf install starknet-foundry 0.45.0

RUN asdf plugin add cairo-coverage
RUN asdf install cairo-coverage 0.1.0

RUN curl -L https://raw.githubusercontent.com/software-mansion/universal-sierra-compiler/master/scripts/install.sh | sh

# switch to root
USER root

# Install Claude
RUN npm install -g @anthropic-ai/claude-code

RUN mkdir -p /workspaces/twamm-distributed-erc20
WORKDIR /workspaces/twamm-distributed-erc20