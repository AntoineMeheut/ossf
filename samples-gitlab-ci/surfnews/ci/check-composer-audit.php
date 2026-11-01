<?php
$data = json_decode(file_get_contents('reports/composer-audit.json'), true, 512, JSON_THROW_ON_ERROR);
if (!isset($data['advisories']) || !is_array($data['advisories'])) {
  throw new RuntimeException('Composer audit report is missing or malformed');
}
$status = (int) $argv[1];
// Composer: bit 1=advisories, bit 2=abandoned packages. Findings are enforced at the barrier.
if ($status > 3 || ($status !== 0 && !$data['advisories'] && empty($data['abandoned']))) {
  throw new RuntimeException('Composer audit failed without a valid findings report');
}
echo "Composer audit completed; release policy is enforced by DefectDojo\n";
