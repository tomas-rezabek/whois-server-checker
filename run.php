<?php
ob_start();
session_start();
include '_inc.db.php';

// Set content type to JSON
header('Content-Type: application/json');

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    if (isset($_POST['domena']) && !empty($_POST['domena'])) {
        $domain = $_POST['domena'];
        $userIP = $_SERVER['REMOTE_ADDR'];
        $log = "./logs/check_" . session_id() . ".log";
        $userID = session_id();



        // Use prepared statements to prevent SQL injection
        $stmt = $pdo->prepare("INSERT INTO form_queries (domain, userIP, userID) VALUES (:domain, :ip_address, :session_id)");

        // Correct the method name from bidn_param to bind_param
        $stmt->bindParam(':domain', $domain);
        $stmt->bindParam(':ip_address', $userIP);
        $stmt->bindParam(':session_id', $userID);

        if ($stmt->execute()) {
            // Ensure the command is escaped properly
	        $prikaz = "bash check.sh " . escapeshellarg($domain) . " " . escapeshellarg($log) . " 2>&1";
            shell_exec($prikaz);
            echo json_encode(['status' => 'success', 'message' => 'Doména v pořádku přidána.', 'log' => $log]);
        } else {
            // Show error message if the insert fails
            echo json_encode(['status' => 'error', 'message' => 'Error: ']);
        }

    } else {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Něco se pokazilo: Doména chybí']);
    }
} else {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Něco se pokazilo: Nesprávná metoda požadavku']);
}

$pdo = null;
ob_end_flush();
?>
