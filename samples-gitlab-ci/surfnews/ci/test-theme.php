<?php
// Exercise the actual Surfnews theme hooks without a production database.
require __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../web/core/lib/Drupal.php';
require __DIR__ . '/../web/themes/aloha_surf/aloha_surf.theme';
function check(bool $condition, string $message): void {
  if (!$condition) { throw new RuntimeException($message); }
}
$hidden = ['data' => ['preview' => ['#access' => FALSE]]];
aloha_surf_preprocess_image_widget($hidden);
check(!isset($hidden['data']['preview']), 'Inaccessible preview must be removed');
$visible = ['data' => ['preview' => ['#access' => TRUE]]];
aloha_surf_preprocess_image_widget($visible);
check(isset($visible['data']['preview']), 'Accessible preview must remain');
$empty = ['data' => []];
aloha_surf_preprocess_image_widget($empty);
check($empty === ['data' => []], 'Missing preview must be supported');
$container = new Symfony\Component\DependencyInjection\ContainerBuilder();
$container->set('date.formatter', new class {
  public function format($timestamp, $type, $format) {
    check($timestamp === 123 && $type === 'custom' && $format === 'j F Y', 'Unexpected date formatter arguments');
    return 'date from Drupal service';
  }
});
Drupal::setContainer($container);
$node = new class { public function getCreatedTime() { return 123; } };
$variables = ['node' => $node];
aloha_surf_preprocess_node($variables);
check($variables['date'] === 'date from Drupal service', 'Node date must come from the formatter');
$info = Symfony\Component\Yaml\Yaml::parseFile(__DIR__ . '/../web/themes/aloha_surf/aloha_surf.info.yml');
check($info['name'] === 'Aloha Surf', 'Expected the original Surfnews theme');
echo "PASS: actual Surfnews theme hooks and metadata\n";
