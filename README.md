# Pacman Logs Analysis with Elastic Stack

This repository contains the Logstash pipeline for processing [Pacman (Arch Linux package manager)](https://gitlab.archlinux.org/pacman/pacman/) logs.

In addition, the repository also includes a minimal Docker Compose setup for the Elastic Stack (Elasticsearch, Kibana, Logstash),
which can be used to store the logs in Elasticsearch and visualize them in Kibana.


## Setup

If you already have an Elastic Stack configuration, you can simply take the [logstash-pacman.conf](./pipeline/logstash-pacman.conf) file and use it with your setup.
Make sure to change the configuration for file paths, Elasticsearch hosts etc.

Otherwise, you can use the provided Docker Compose setup (see the [compose.yaml](./compose.yaml) file).
Pull the Docker images for Elasticsearch, Kibana, and Logstash:
```bash
docker compose pull
```
The `compose.yaml` file already bind mounts the `/var/log/pacman.log` file to the Logstash ingest data directory.
Feel free to change the file and/or path depending on your setup.

Make sure to set the environment variables (such as passwords and Kibana encryption keys) in the `.env` file. Use `.env.example` as a reference.
To generate Kibana encryption keys, you can use the `generate-kibana-keys` service, e.g.:
```bash
docker compose --profile kibana-keys run --rm generate-kibana-keys
```


## Elastic Common Schema

The [ECS_MAPPING.md](./ECS_MAPPING.md) file lists the mappings for different types of Pacman log lines to [Elastic Common Schema (ECS)](https://www.elastic.co/docs/reference/ecs).
We tried to find a balance between ECS-compliancy, semantics, and consistency.

Note that this mapping is not exhaustive and is based on the Pacman log lines that we have encountered (with the corresponding format).
It may be updated in the future if we encounter other types of log lines.


## Example logs

In the [example-logs](./example-logs/) directory, you can find some old logs which you can check to get the idea of Pacman logs. 
You can also use these logs if you do not have a `/var/log/pacman.log` file and you want to try out some queries and visualizations in Kibana.
To do this, bind mount the `example-logs` directory to `/usr/share/logstash/ingest-data` in the `compose.yaml` file.

In addition, [test-logs](./test-logs/) directory contains some logs which can be used for testing the Logstash pipeline.
These files should only be used during development (e.g. using only the stdout output plugin) and contain various kinds of log lines (with hardcoded timestamps).


## Usage

Deploy the Elastic Stack using standard Docker Compose commands, e.g.:
```bash
# Start Elasticsearch and Kibana
docker compose up es kibana
# Start Logstash
docker compose up logstash
# Start all services
docker compose up
```

Once the Elasticsearch service (`es`) is running, copy the public CA certificate for verification:
```bash
docker compose cp es:/usr/share/elasticsearch/config/certs/ca/ca.crt .
```

To test connectivity to Elasticsearch, run:
```bash
curl --cacert ca.crt -u "elastic:$ELASTIC_PASSWORD" -XGET 'https://localhost:9200?pretty'
```

To access Kibana, enter `https://localhost:5601` in your browser.
Note that including the scheme `https://` is necessary, since Kibana is configured to use HTTPS.

To prevent certificate warnings/errors, import the CA certificate to the trust policy store
(e.g. see [this wiki page](https://wiki.archlinux.org/title/User:Grawity/Adding_a_trusted_CA_certificate) for more information).

In the [dashboards](./dashboards/) directory, you can find NDJSON files containing example dashboard and related objects.
Once Elasticsearch has ingested the logs, you can import the corresponding NDJSON file to Kibana:
- `pacman_example_logs_dashboard.ndjson`: use this file with the `example` data stream namespace and logs from the `example-logs` directory (see `logstash` service configuration in `compose.yaml`).
  This will create "Pacman Example Logs" data view (with the index pattern `logs-pacman-example`) and "Pacman Example Logs Dashboard" dashboard.
  Since there are not many logs in the `example-logs` directory, this dashboard is not particularly interesting and is only used for illustration purposes.
- `pacman_logs_dashboard.ndjson`: use this file with the `default` data stream namespace and logs from the `/var/log/pacman.log` file (see `logstash` service configuration in `compose.yaml`).
  This will create "Pacman Default Logs" data view (with the index pattern `logs-pacman-default`) and "Pacman Logs Dashboard" dashboard.

To import an NDJSON file with a dashboard, go to **Stack Management > Saved Objects**, click **Import**, select the NDJSON file, and choose "Create new objects with random IDs"
(see [Kibana documentation](https://www.elastic.co/docs/explore-analyze/dashboards/import-dashboards) for more information).
To see the available [data views](https://www.elastic.co/docs/explore-analyze/find-and-organize/data-views), go to **Stack Management > Data Views**.

Feel free to create your own dashboards or modify existing ones.
