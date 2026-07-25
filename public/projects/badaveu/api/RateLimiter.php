<?php

class RateLimiter {

    private string $cacheDir;

    public function __construct() {
        $this->cacheDir = __DIR__ . '/rate_cache/';
        if (!is_dir($this->cacheDir)) {
            mkdir($this->cacheDir, 0750, true);
        }
    }

    private function getIp(): string {
        $ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';

        // Only trust X-Forwarded-For when the request comes from a known trusted proxy.
        // Set TRUSTED_PROXY=<proxy-ip> in .env to enable this (e.g. TRUSTED_PROXY=127.0.0.1).
        // Leaving it empty (default) disables header-based IP resolution entirely.
        $trustedProxy = defined('TRUSTED_PROXY') ? TRUSTED_PROXY : '';
        if ($trustedProxy !== '' && $ip === $trustedProxy) {
            $forwarded = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? '';
            if ($forwarded !== '') {
                $ip = trim(explode(',', $forwarded)[0]);
            }
        }

        return preg_replace('/[^a-fA-F0-9.:_-]/', '_', $ip);
    }

    private function getCacheFile(string $action, string $ip): string {
        return $this->cacheDir . hash('sha256', $action . '_' . $ip) . '.json';
    }

    /**
     * Check and record a hit. Returns ['allowed' => bool, 'retry_after' => int].
     *
     * @param string $action      Identifier (new_incident, login, vote)
     * @param int    $maxHits     Maximum allowed hits in the window
     * @param int    $windowSecs  Window length in seconds
     * @param int    $blockSecs   How long to block after exceeding (0 = use window)
     */
    public function check(string $action, int $maxHits, int $windowSecs, int $blockSecs = 0): array {
        $ip   = $this->getIp();
        $file = $this->getCacheFile($action, $ip);
        $now  = time();

        $data = ['hits' => [], 'blocked_until' => 0];

        // Exclusive lock covers the full read-modify-write cycle, preventing TOCTOU races
        // where two concurrent requests could both read stale state and bypass the limit.
        $fp = fopen($file, 'c+');
        if ($fp === false) {
            // Cannot open cache file — fail open to avoid blocking legitimate requests.
            return ['allowed' => true, 'retry_after' => 0];
        }

        if (!flock($fp, LOCK_EX)) {
            fclose($fp);
            return ['allowed' => true, 'retry_after' => 0];
        }

        $raw = stream_get_contents($fp);
        if ($raw !== false && $raw !== '') {
            $decoded = json_decode($raw, true);
            if (is_array($decoded)) {
                $data = $decoded;
            }
        }

        // Check if currently blocked
        if (($data['blocked_until'] ?? 0) > $now) {
            $retryAfter = $data['blocked_until'] - $now;
            flock($fp, LOCK_UN);
            fclose($fp);
            return ['allowed' => false, 'retry_after' => $retryAfter];
        }

        // Remove hits outside the current window
        $data['hits'] = array_values(
            array_filter($data['hits'], fn(int $t): bool => $t > ($now - $windowSecs))
        );

        $result = ['allowed' => true, 'retry_after' => 0];

        if (count($data['hits']) >= $maxHits) {
            $block = $blockSecs > 0 ? $blockSecs : $windowSecs;
            $data['blocked_until'] = $now + $block;
            $result = ['allowed' => false, 'retry_after' => $block];
        } else {
            $data['hits'][] = $now;
        }

        ftruncate($fp, 0);
        rewind($fp);
        fwrite($fp, json_encode($data));
        flock($fp, LOCK_UN);
        fclose($fp);

        return $result;
    }

    /**
     * Enforce a rate limit; sends HTTP 429 and exits if exceeded.
     */
    public function enforce(string $action, int $maxHits, int $windowSecs, int $blockSecs = 0): void {
        $result = $this->check($action, $maxHits, $windowSecs, $blockSecs);
        if (!$result['allowed']) {
            http_response_code(429);
            $minutes = (int) ceil($result['retry_after'] / 60);
            echo json_encode([
                "status"      => "error",
                "message"     => "Massa sol·licituds. Torna a intentar-ho en {$minutes} minuts.",
                "retry_after" => $result['retry_after']
            ]);
            exit;
        }
    }

    /** Periodically purge stale cache files (1 in 20 chance). */
    public function cleanup(): void {
        if (rand(1, 20) !== 1) return;
        $now = time();
        foreach (glob($this->cacheDir . '*.json') as $file) {
            $raw = @file_get_contents($file);
            if (!$raw) { @unlink($file); continue; }
            $data = json_decode($raw, true);
            if (!is_array($data)) { @unlink($file); continue; }
            $latestHit  = !empty($data['hits']) ? max($data['hits']) : 0;
            $blockedEnd = $data['blocked_until'] ?? 0;
            if ($latestHit < $now - 7200 && $blockedEnd < $now) {
                @unlink($file);
            }
        }
    }
}
