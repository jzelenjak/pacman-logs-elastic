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
Make sure to set the passwords and Kibana encryption keys in the `.env` file (use `.env.example` as a reference).


## Usage

Deploy the Elastic Stack using standard Docker Compose commands, e.g.:
```bash
# Start all nodes
docker compose up
# Start only Elasticsearch and Kibana
docker compose up es kibana
```

Once the Elasticsearch service (`es`) is running, copy the public CA certificate for verification:
```bash
docker compose cp es:/usr/share/elasticsearch/config/certs/ca/ca.crt .
```

To test connectivity to Elasticsearch, run:
```bash
curl --cacert ca.crt -u elastic:$ELASTIC_PASSWORD -XGET 'https://localhost:9200?pretty'
```

To access Kibana, type `https://localhost:5601` in your browser.
Note that including the scheme `https://` is necessary, since Kibana is configured to use HTTPS.

To prevent certificate warnings/errors, import the CA certificate to the trust policy store
(e.g. see [this wiki page](https://wiki.archlinux.org/title/User:Grawity/Adding_a_trusted_CA_certificate) for more information).
