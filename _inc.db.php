<?php

$host = 'localhost';
$db = 'form_data';
$user = 'root';
$pass = '';

try {
	$pdo = new PDO("mysql:host=$host;dbname=$db", $user, $pass);
	//PDO error mode to exception
	$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
	echo "Connection failed: " . $e->getMessage();
} 
?>
