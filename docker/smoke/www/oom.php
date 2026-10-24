<?php
// Exceeding memory_limit: unpatched PHP bails out and runs shutdown functions;
// the backport prints the fatal error to stderr and exits the worker immediately.
@unlink('/tmp/shutdown_ran');
register_shutdown_function(function () { file_put_contents('/tmp/shutdown_ran', '1'); });
ini_set('memory_limit', '16M');
echo "before\n";
$s = str_repeat('x', 64 * 1024 * 1024);
echo "after\n";
