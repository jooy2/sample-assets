<?php

declare(strict_types=1);

// The string functions worth knowing, including the PHP 8 additions that
// replace the old strpos idioms.

$line = 'Alder Cross,Amber,2,true';

echo 'length: ', strlen($line), PHP_EOL;
echo 'upper: ', strtoupper($line), PHP_EOL;
echo 'title: ', ucwords(strtolower('QUILL WHARF STATION')), PHP_EOL;

// PHP 8 replaced `strpos(...) !== false` with three readable functions.
echo 'contains Amber: ', var_export(str_contains($line, 'Amber'), true), PHP_EOL;
echo 'starts with Alder: ', var_export(str_starts_with($line, 'Alder'), true), PHP_EOL;
echo 'ends with true: ', var_export(str_ends_with($line, 'true'), true), PHP_EOL;

$fields = explode(',', $line);
echo count($fields), ' fields, last is ', end($fields), PHP_EOL;
echo 'joined: ', implode(' | ', array_slice($fields, 0, 3)), PHP_EOL;

echo 'replaced: ', str_replace(',', '; ', $line), PHP_EOL;
echo 'repeated: ', str_repeat('-', 24), PHP_EOL;
echo 'padded: |', str_pad('left', 12), '|', str_pad('right', 12, ' ', STR_PAD_LEFT), '|', PHP_EOL;
echo 'trimmed: [', trim('   spaced out   '), ']', PHP_EOL;
echo 'substr: ', substr($line, 0, 11), PHP_EOL;
echo 'position of comma: ', strpos($line, ','), PHP_EOL;

printf("printf: %-14s %5.2f %s%s", 'Alder Cross', 3.4, str_pad('2', 3, '0', STR_PAD_LEFT), PHP_EOL);
echo sprintf('sprintf: %08.3f %x %b %s', 3.14159, 255, 5, 'end'), PHP_EOL;

// Multibyte strings need the mb_ functions to count characters, not bytes.
$unicode = 'café naïve';
echo 'bytes ', strlen($unicode), ' vs characters ', mb_strlen($unicode), PHP_EOL;
echo 'mb_substr: ', mb_substr($unicode, 0, 4), PHP_EOL;
echo 'mb_strtoupper: ', mb_strtoupper($unicode), PHP_EOL;

// Heredoc interpolates; nowdoc does not.
$name = 'Alder Cross';
echo <<<REPORT
    Station: {$name}
    Zone:    2
    REPORT, PHP_EOL;

echo <<<'LITERAL'
    Not interpolated: {$name}
    LITERAL, PHP_EOL;

echo 'wordwrap:', PHP_EOL, wordwrap(
    'The tide came in and the tide went out and the shore stayed where it was',
    28,
    PHP_EOL . '  '
), PHP_EOL;

echo 'slug: ', strtolower(preg_replace('/[^a-z0-9]+/i', '-', trim($line))), PHP_EOL;
echo 'nl2br is for HTML, number_format for people: ', number_format(1234567.891, 2), PHP_EOL;
