{{before_vhost_configuration}}
<VirtualHost {{https_listen_addresses}}>
  {{server_name_configuration}}
  SSLEngine on
  SSLCertificateFile "{{APACHE_CONF_DIR}}/bitnami/certs/server.crt"
  SSLCertificateKeyFile "{{APACHE_CONF_DIR}}/bitnami/certs/server.key"
  {{additional_configuration}}
</VirtualHost>
