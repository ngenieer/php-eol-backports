<?php
// multipart/form-data goes through rfc1867.c (header filtering and body-part limit in the patch)
echo "post=", json_encode($_POST), "\n";
foreach ($_FILES as $field => $f) {
    $data = $f['error'] === UPLOAD_ERR_OK ? file_get_contents($f['tmp_name']) : '';
    echo "file[$field]=", $f['name'], "|", $f['type'], "|", $f['size'], "|err=", $f['error'], "|", trim($data), "\n";
}
echo "files=", count($_FILES), "\n";
