<?php
// Nested GET/POST arrays go through php_register_variable_ex (array_init_singleton in the patch)
ksort($_GET); ksort($_POST);
echo "get=", json_encode($_GET), "\n";
echo "post=", json_encode($_POST), "\n";
