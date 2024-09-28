<?php

$prikaz = 'sh /var/www/html/checker/check.sh > /var/www/html/checker/logs/check.log 2>&1 &';

shell_exec($prikaz);

?>