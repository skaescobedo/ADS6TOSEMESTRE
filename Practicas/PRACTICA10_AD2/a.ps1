multiotp-database-format-v3

; Configuración general
default_otp_algorithm=sha1
default_otp_length=6
default_otp_timeout=30
default_token_type=totp
actual_version=5.9.9.1
enable_log=1
enable_cache=1
case_sensitive_users=0
language=en
timezone=Europe/Zurich
issuer=multiOTP

; Almacenamiento de datos local
backend_type=files
backend_encoding=UTF-8
backend_type_validated=0

; LDAP / Active Directory
ldap_activated=1
ldap_server_type=1
ldap_domain_controllers=WINSERVER2025.reprobados.com
ldap_port=636
ldap_ssl=1
ldaptls_reqcert=never
ldap_bind_dn=CN=multiotpbind,CN=Users,DC=reprobados,DC=com
ldap_server_password=Mtp2025ldaps!
ldap_users_dn=CN=Users,DC=reprobados,DC=com
ldap_base_dn=CN=Users,DC=reprobados,DC=com
ldap_in_group=
ldap_filter=
ldap_recursive_groups=1
ldap_cache_on=1
ldap_hash_cache_time=604800
ldap_time_limit=30
ldap_network_timeout=10

; Otros (puedes dejar estos valores)
allow_http_get=1
console_authentication=0
debug=0
log=0
sms_code_allowed=1
scratch_passwords_amount=10
scratch_passwords_digits=6
max_block_failures=6
max_delayed_failures=3
server_secret:=dGx9cn5qeFV7fFJ5RGR/cGd4
