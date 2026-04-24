FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Homebrew on Linux needs these present before the install script runs
RUN apt-get update && apt-get install -y \
    build-essential curl file git \
    && rm -rf /var/lib/apt/lists/*

# Homebrew refuses to run as root — create a non-root user.
# Pre-create the Homebrew prefix owned by devuser so brew never needs sudo.
RUN useradd -m -s /bin/bash devuser \
    && mkdir -p /home/linuxbrew/.linuxbrew \
    && chown -R devuser:devuser /home/linuxbrew

USER devuser
WORKDIR /home/devuser

# dev_env.sh and dev_env.tsv are mounted at run time (see run_tests.sh)
CMD ["/bin/bash", "dev_env.sh"]
