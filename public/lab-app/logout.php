<?php
require_once __DIR__ . '/../lab/auth.php';
lab_logout_user();
lab_redirect('login.php');
