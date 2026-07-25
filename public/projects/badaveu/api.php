<?php
// api.php
header('Content-Type: application/json');
require 'db.php';

$method = $_SERVER['REQUEST_METHOD'];

// 1. OBTENER INCIDENCIAS (GET)
if ($method === 'GET') {
    $stmt = $pdo->query("SELECT * FROM incidencias ORDER BY fecha DESC");
    echo json_encode($stmt->fetchAll());
    exit;
}

// 2. GUARDAR INCIDENCIA (POST)
if ($method === 'POST') {
    try {
        $titulo = $_POST['titulo'] ?? '';
        $descripcion = $_POST['descripcion'] ?? '';
        $categoria = $_POST['categoria'] ?? '';
        $tipo = $_POST['tipo'] ?? '';
        $lat = $_POST['lat'] ?? '';
        $lng = $_POST['lng'] ?? '';
        $cp = $_POST['cp'] ?? '';
        
        // Manejo de imagen
        $foto_url = null;
        if (isset($_FILES['foto']) && $_FILES['foto']['error'] === UPLOAD_ERR_OK) {
            $ext = pathinfo($_FILES['foto']['name'], PATHINFO_EXTENSION);
            $filename = uniqid() . "." . $ext;
            $uploadDir = 'uploads/';
            if (!is_dir($uploadDir)) mkdir($uploadDir, 0777, true);
            
            if(move_uploaded_file($_FILES['foto']['tmp_name'], $uploadDir . $filename)){
                $foto_url = $uploadDir . $filename;
            }
        }

        $sql = "INSERT INTO incidencias (titulo, descripcion, categoria, tipo_problema, lat, lng, cp, foto_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
        $stmt= $pdo->prepare($sql);
        $stmt->execute([$titulo, $descripcion, $categoria, $tipo, $lat, $lng, $cp, $foto_url]);

        echo json_encode(['status' => 'success', 'message' => 'Reporte guardado']);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
    exit;
}
?>