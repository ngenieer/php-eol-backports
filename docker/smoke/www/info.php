<?php
$oc = function_exists('opcache_get_status') ? opcache_get_status(false) : false;
echo "version=", PHP_VERSION, "\n";
echo "sapi=", PHP_SAPI, "\n";
echo "pid=", getmypid(), "\n";
echo "opcache=", ($oc && $oc['opcache_enabled']) ? "on" : "off", "\n";
echo "ext=", implode(',', array_filter(['mysqli', 'pdo_mysql', 'gd', 'session'], 'extension_loaded')), "\n";
