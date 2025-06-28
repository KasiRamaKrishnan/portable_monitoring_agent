FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /opt/agent

# Use alternative mirror to avoid archive.ubuntu.com issues
#RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirror.math.princeton.edu/pub/ubuntu/|g' /etc/apt/sources.list

RUN mkdir -p /var/log/supervisor
# Install dependencies, including missing ones for Grafana .deb
RUN apt-get update && \
    apt-get install -y wget curl unzip supervisor gnupg2 apt-transport-https software-properties-common \
    libfontconfig1 musl && \
    mkdir -p /etc/prometheus /etc/loki /etc/grafana/provisioning /var/lib/prometheus /var/lib/grafana /var/lib/loki /opt/bin  && mkdir -p /tmp/loki/index /tmp/loki/cache /tmp/loki/chunks

# Install Prometheus
RUN wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz && \
    tar -xvf prometheus-2.52.0.linux-amd64.tar.gz && \
    mv prometheus-2.52.0.linux-amd64/prometheus prometheus-2.52.0.linux-amd64/promtool /usr/local/bin/ && \
    rm -rf prometheus-2.52.0*

# Install Loki
RUN wget https://github.com/grafana/loki/releases/download/v2.9.4/loki-linux-amd64.zip && \
    unzip loki-linux-amd64.zip && \
    chmod +x loki-linux-amd64 && \
    mv loki-linux-amd64 /usr/local/bin/loki && \
    rm loki-linux-amd64.zip

# Install Promtail
RUN wget https://github.com/grafana/loki/releases/download/v2.9.4/promtail-linux-amd64.zip && \
    unzip promtail-linux-amd64.zip && \
    chmod +x promtail-linux-amd64 && \
    mv promtail-linux-amd64 /usr/local/bin/promtail && \
    rm promtail-linux-amd64.zip

# Copy Promtail config
COPY promtail-config.yaml /etc/promtail/promtail-config.yaml


# Install Grafana Enterprise
RUN wget https://dl.grafana.com/enterprise/release/grafana-enterprise_10.4.1_amd64.deb && \
    dpkg -i grafana-enterprise_10.4.1_amd64.deb && \
    rm grafana-enterprise_10.4.1_amd64.deb

RUN sed -i 's|^;provisioning = .*|provisioning = /etc/grafana/provisioning|' /etc/grafana/grafana.ini


# Copy configuration files
COPY prometheus.yml /etc/prometheus/prometheus.yml
COPY loki-config.yaml /etc/loki/loki-config.yaml
COPY supervisord.conf /etc/supervisor/supervisord.conf

COPY grafana/provisioning /etc/grafana/provisioning
COPY grafana/dashboards /var/lib/grafana/dashboards

# Expose ports for Prometheus, Grafana, and Loki
EXPOSE 9090 3000 3100

# Start all components using Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

