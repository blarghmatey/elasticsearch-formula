{% from "elasticsearch/map.jinja" import elasticsearch with context %}

{% set os_family = grains['os_family'] %}
{% set cluster_name = salt['pillar.get']('elasticsearch:cluster_name') %}
{% set node_name = salt['pillar.get']('elasticsearch:node_name') %}
{% set use_cors = salt['pillar.get']('elasticsearch:use_cors, True) %}

setup_elasticsearch_pkg_repo:
  pkgrepo.managed:
    - humanname: ElasticSearch
    {% if os_family == 'Debian' %}
    - name: deb http://packages.elasticsearch.org/elasticsearch/1.3/debian stable main
    {% elif os_family == 'RedHat' %}
    - baseurl: http://packages.elasticsearch.org/elasticsearch/1.3/centos
    - gpgcheck: 1
    - enabled: 1
    {% endif %}
    - key_url: http://packages.elasticsearch.org/GPG-KEY-elasticsearch
    - require_in:
        - pkg: elasticsearch_pkg_reqs

sysctl_settings:
  file.managed:
    - name: /etc/sysctl.d/60-elasticsearch.conf
    - source: salt://elasticsearch/files/elasticsearch_sysctl.conf

elasticsearch_pkg_reqs:
  pkg.installed:
    - pkgs: {{ elasticsearch.pkgs }}
    - require:
        - file: sysctl_settings

{% if cluster_name %}
elasticsearch_cluster_name:
  file.replace:
    - name: /etc/elasticsearch/elasticsearch.yml
    - pattern: ^#?cluster.name:.*?$
    - repl: cluster.name: {{ cluster_name }}
    - append_if_not_found: True
    - require:
        - pkg: elasticsearch_pkg_reqs
    - require_in:
        - service: start_elasticsearch
{% endif %}

{% if node_name %}
elasticsearch_node_name:
  file.replace:
    - name: /etc/elasticsearch/elasticsearch.yml
    - pattern: ^#?node.name:.*?$
    - repl: node.name: {{ node_name }}
    - append_if_not_found: True
    - require:
        - pkg: elasticsearch_pkg_reqs
    - require_in:
        - service: start_elasticsearch
{% endif %}

{% if use_cors %}
elasticsearch_cors_config:
  file.append:
    - name: /etc/elasticsearch/elasticsearch.yml
    - text: |
      http.cors.enable: true
      http.cors.allow-origin: {{ salt['pillar.get']('elasticsearch:allow-origin', '*') }}
{% endif %}

start_elasticsearch:
  service.running:
    - name: elasticsearch
    - enable: True
    - require:
        - pkg: elasticsearch_pkg_reqs