# Use the acme customized intermediate falco container to start with
FROM gcr.io/pm-registry/falco:latest

LABEL repository="https://github.com/acme/security.git"
LABEL maintainer="security@acme.com"
LABEL purpose="siem"

# Install FluentBit package key
RUN curl -L http://packages.fluentbit.io/fluentbit.key | apt-key add -

# Get Current
RUN echo "deb https://packages.fluentbit.io/debian/buster buster main" >> /etc/apt/sources.list
RUN DEBIAN_FRONTEND=noninteractive apt-get -y update \
  && DEBIAN_FRONTEND=noninteractive apt -y --fix-broken install \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common \
  apt-transport-https sudo libgnutls28-dev curl td-agent-bit 

# Customize the Service configuration
COPY /etc/falco/falco.yaml /etc/falco/falco.yaml
# no need to modifiy falco_rules.yaml typically

# Our custom rules falco_rules.local.yaml
COPY /etc/falco/falco_rules.local.yaml /etc/falco/falco_rules.local.yaml
# Cluster worker audit rules
COPY /etc/falco/k8s_audit_rules.yaml /etc/falco/k8s_audit_rules.yaml

# Supply our FluentBit configuration to ship events to Sumologic
COPY /etc/td-agent-bit/td-agent-bit.conf /etc/td-agent-bit/td-agent-bit.conf 
COPY /etc/startup.sh /startup.sh

# Run falco as falco user via sudo
RUN useradd falco
RUN usermod -a -G falco falco
RUN usermod -a -G sudo falco
RUN echo "falco ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN usermod -a -G adm falco
COPY /bashrc "/home/falco/.bashrc"
RUN chown falco:falco /home/falco/.bashrc
WORKDIR "/home/falco"
USER falco
