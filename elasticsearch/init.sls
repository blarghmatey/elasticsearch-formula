{% from "elasticsearch/map.jinja" import elasticsearch with context %}

{% set os_family = grains['os_family'] %}
{% set cluster_name = salt['pillar.get']('elasticsearch:cluster_name') %}
{% set node_name = salt['pillar.get']('elasticsearch:node_name') %}
{% set use_cors = salt['pillar.get']('elasticsearch:use_cors', True) %}
{% set cors_allow_origin = salt['pillar.get']('elasticsearch:allow-origin', '*') %}
{% set plugin_list = salt['pillar.get']('elasticsearch:plugins', []) %}
{% set http_host = salt['pillar.get']('elasticsearch:http_host', '_non_loopback:ipv4_') %}

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

elasticsearch_config:
  file.managed:
    - name: /etc/elasticsearch/elasticsearch.yml
    - source: salt://elasticsearch/files/elasticsearch.yml
    - template: jinja
    - makedirs: True
    - context:
        cluster_name: {{ cluster_name }}
        node_name: {{ node_name }}
        http_host: {{ http_host }}
        use_cors: {{ use_cors }}
        cors_allow_origin: '{{ cors_allow_origin }}'

start_elasticsearch:
  service.running:
    - name: elasticsearch
    - enable: True
    - require:
        - pkg: elasticsearch_pkg_reqs
    - watch:
        - file: elasticsearch_config

{% for plugin in plugin_list %}
elasticsearch_install_{{ plugin.name }}:
  cmd.run:
    - name: /usr/share/elasticsearch/bin/plugin -install {{ plugin.path }}
    - unless: /usr/share/elasticsearch/bin/plugin -l | grep {{ plugin.name }} | wc -l
{% endfor %}
