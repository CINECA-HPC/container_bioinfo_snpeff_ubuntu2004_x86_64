# Build stage with Spack pre-installed and ready to be used
FROM cinecahpc/container_spack_ubuntu2004_x86_64:latest as builder


# What we want to install and how we want to install it
# is specified in a manifest file (spack.yaml)
RUN mkdir /opt/spack-environment \
&&  (echo "spack:" \
&&   echo "  specs:" \
&&   echo "  - snpeff@2017-11-24 ^openjdk@11.0.2" \
&&   echo "  concretization: together" \
&&   echo "  config:" \
&&   echo "    install_tree: /opt/software" \
&&   echo "  view: /opt/view") > /opt/spack-environment/spack.yaml

# PATCH snpeff package installation

RUN  sed "s/'jdk'/'openjdk'/" /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py > /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py.NEW && mv /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py.NEW /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py

RUN sed "s/'java'/'openjdk'/" /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py > /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py.NEW && mv /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py.NEW /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py

RUN sed "s/\^java/\^openjdk/" /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py > /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py.NEW && mv /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py.NEW /opt/spack/var/spack/repos/builtin/packages/snpeff/package.py

# Install the software, remove unnecessary deps
RUN cd /opt/spack-environment && spack env activate . && spack install --fail-fast && spack gc -y

# Strip all the binaries
RUN find -L /opt/view/* -type f -exec readlink -f '{}' \; | \
    xargs file -i | \
    grep 'charset=binary' | \
    grep 'x-executable\|x-archive\|x-sharedlib' | \
    awk -F: '{print $1}' | xargs strip -s

# Modifications to the environment that are necessary to run
RUN cd /opt/spack-environment && \
    spack env activate --sh -d . >> /etc/profile.d/z10_spack_environment.sh


# Bare OS image to run the installed executables
FROM ubuntu:20.04

COPY --from=builder /opt/spack-environment /opt/spack-environment
COPY --from=builder /opt/software /opt/software
COPY --from=builder /opt/view /opt/view
COPY --from=builder /etc/profile.d/z10_spack_environment.sh /etc/profile.d/z10_spack_environment.sh


RUN echo 'export PS1="\[$(tput bold)\]\[$(tput setaf 1)\][snpeff]\[$(tput setaf 2)\]\u\[$(tput sgr0)\]:\w $ "' >> ~/.bashrc

LABEL "app"="snpeff"

ENTRYPOINT ["/bin/bash", "--rcfile", "/etc/profile", "-l"]
