<?php
/**
 * phpMyAdmin configuration for MySQL Cluster via ProxySQL
 * Copy this to your phpMyAdmin config directory
 */

/* Server parameters */
$cfg['Servers'][1]['host'] = '192.168.11.122';
$cfg['Servers'][1]['port'] = '6033';
$cfg['Servers'][1]['socket'] = '';
$cfg['Servers'][1]['connect_type'] = 'tcp';
$cfg['Servers'][1]['extension'] = 'mysqli';
$cfg['Servers'][1]['auth_type'] = 'cookie';
$cfg['Servers'][1]['user'] = '';
$cfg['Servers'][1]['password'] = '';
$cfg['Servers'][1]['compress'] = false;
$cfg['Servers'][1]['AllowNoPassword'] = false;

/* Optional: Set specific database for login */
$cfg['Servers'][1]['only_db'] = array('appdb', 'db-mpp');

/* Advanced settings for ProxySQL compatibility */
$cfg['Servers'][1]['DisableIS'] = true;  // Disable INFORMATION_SCHEMA usage
$cfg['Servers'][1]['hide_db'] = '^(information_schema|performance_schema|mysql|sys)$';

/* Connection settings */
$cfg['Servers'][1]['verbose'] = 'MySQL Cluster via ProxySQL';
$cfg['DefaultLang'] = 'en';
$cfg['ServerDefault'] = 1;

/* Disable problematic features for ProxySQL */
$cfg['MaxNavigationItems'] = 50;
$cfg['NavigationTreeEnableGrouping'] = false;
$cfg['QueryHistoryDB'] = false;
$cfg['QueryHistoryMax'] = 25;

/* Authentication settings */
$cfg['blowfish_secret'] = 'your-secret-key-here-32-chars-long!';
?>
