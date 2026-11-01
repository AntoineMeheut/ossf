<?php
// Runtime settings only: no workstation database, content or credentials are copied.
$url = parse_url(getenv('DATABASE_URL') ?: '');
if (!$url || !isset($url['host'], $url['path'], $url['user'])) {
  throw new RuntimeException('Supply a PostgreSQL DATABASE_URL at deployment.');
}
$databases['default']['default'] = [
  'driver' => 'pgsql', 'namespace' => 'Drupal\\pgsql\\Driver\\Database\\pgsql',
  'database' => ltrim($url['path'], '/'), 'username' => rawurldecode($url['user']),
  'password' => rawurldecode($url['pass'] ?? ''), 'host' => $url['host'],
  'port' => $url['port'] ?? 5432, 'prefix' => '',
];
$settings['hash_salt'] = getenv('DRUPAL_HASH_SALT') ?: throw new RuntimeException('Supply DRUPAL_HASH_SALT.');
$settings['trusted_host_patterns'] = explode(',', getenv('DRUPAL_TRUSTED_HOSTS') ?: '^localhost$');
