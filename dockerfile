# ... (Previous Stage 1: Gather Binaries - SAME AS BEFORE) ...
FROM ubuntu:22.04 as builder
ENV PROMETHEUS_VERSION=2.45.0
ENV NODE_EXPORTER_VERSION=1.6.1
RUN apt-get update && apt-get install -y wget tar
RUN wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz && \
    tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz && \
    mv prometheus-${PROMETHEUS_VERSION}.linux-amd64 /prometheus-bin
RUN wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz && \
    tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz && \
    mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /bin/node_exporter

# ... (Previous Stage 2: Final Image - SAME AS BEFORE) ...
FROM grafana/grafana:latest
USER root
RUN apk add --no-cache supervisor
COPY --from=builder /prometheus-bin/prometheus /bin/prometheus
COPY --from=builder /prometheus-bin/promtool /bin/promtool
COPY --from=builder /bin/node_exporter /bin/node_exporter
RUN mkdir -p /etc/prometheus /var/lib/prometheus /var/log/supervisor /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards
COPY main.json /var/lib/grafana/dashboards/main.json
RUN echo '[supervisord] \n\
nodaemon=true \n\
\n\
[program:grafana] \n\
command=/run.sh \n\
autorestart=true \n\
stdout_logfile=/var/log/supervisor/grafana.log \n\
stderr_logfile=/var/log/supervisor/grafana.err \n\
\n\
[program:prometheus] \n\
command=/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus \n\
autorestart=true \n\
stdout_logfile=/var/log/supervisor/prometheus.log \n\
stderr_logfile=/var/log/supervisor/prometheus.err \n\
\n\
[program:node-exporter] \n\
command=/bin/node_exporter \n\
autorestart=true \n\
stdout_logfile=/var/log/supervisor/node_exporter.log \n\
stderr_logfile=/var/log/supervisor/node_exporter.err \n\
' > /etc/supervisord.conf
RUN echo 'global: \n\
  scrape_interval: 15s \n\
scrape_configs: \n\
  - job_name: "node-exporter" \n\
    static_configs: \n\
      - targets: ["localhost:9100"] \n\
  - job_name: "prometheus" \n\
    static_configs: \n\
      - targets: ["localhost:9090"] \n\
' > /etc/prometheus/prometheus.yml
RUN echo 'apiVersion: 1 \n\
datasources: \n\
  - name: Prometheus \n\
    type: prometheus \n\
    access: proxy \n\
    url: http://localhost:9090 \n\
    isDefault: true \n\
' > /etc/grafana/provisioning/datasources/datasource.yaml
RUN echo 'apiVersion: 1 \n\
providers: \n\
  - name: "Default" \n\
    orgId: 1 \n\
    folder: "" \n\
    type: file \n\
    disableDeletion: false \n\
    updateIntervalSeconds: 10 \n\
    options: \n\
      path: /var/lib/grafana/dashboards \n\
' > /etc/grafana/provisioning/dashboards/dashboard.yaml

# ==============================================================================
# CONFIGURATION FOR TOOL & ANONYMOUS ACCESS
# ==============================================================================

ARG ENDPOINT_NAME=grafana
ENV GF_SERVER_HTTP_PORT=5000
ENV GF_SERVER_ROOT_URL=%(protocol)s://%(domain)s:%(http_port)s/${ENDPOINT_NAME}/
ENV GF_SERVER_SERVE_FROM_SUB_PATH=true

# 1. ENABLE ANONYMOUS ACCESS (No Login Required)
ENV GF_AUTH_ANONYMOUS_ENABLED=true

# 2. SET ROLE TO VIEWER (They can see, but cannot edit/delete anything)
ENV GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer

# 3. HIDE THE LOGIN FORM (Since we don't need it)
ENV GF_AUTH_DISABLE_LOGIN_FORM=true

# 4. ALLOW IFRAME EMBEDDING
ENV GF_SECURITY_ALLOW_EMBEDDING=true

EXPOSE 5000
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]