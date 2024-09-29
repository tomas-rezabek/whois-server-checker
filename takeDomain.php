<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
  if(empty($_POST['domena'])) {
    echo "POST request is empty";
    exit;
  } else {
    if (isset($_POST['domena'])) { // Check if the key exists
      $DOMENA = $_POST['domena'];
      $cfg = "DOMENA=$DOMENA";
      file_put_contents('./config/domena.cfg', $cfg);
      echo "OK Doména v pořádku vložena do konfigu.";
    } else {
      echo "Error: domena field is missing.";
    }
  }
} else {
  echo 'Něco se pokazilo';
  header('Location: index.php');
  exit;
}


