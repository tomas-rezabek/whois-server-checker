<?php

if ($_SERVER["REQUEST_METHOD"] == "POST") {
  $DOMENA = escapeshellarg($_POST[DOMENA]);
  file_put_contents('../config/domena.cfg', $DOMENA);
} else {
  echo 'Něco se pokazilo';
};

?>