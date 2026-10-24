<?php
session_save_path('/tmp');
session_start();
$_SESSION['n'] = isset($_SESSION['n']) ? $_SESSION['n'] + 1 : 1;
echo "sid=", session_id(), "\n";
echo "n=", $_SESSION['n'], "\n";
