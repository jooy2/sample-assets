<?php

declare(strict_types=1);

// Reading and writing files: the whole-file helpers, the handle API, and
// the CSV functions in between.

$directory = sys_get_temp_dir() . '/sample-assets-' . bin2hex(random_bytes(4));
mkdir($directory);
$path = "{$directory}/stations.csv";

$rows = [
    ['station', 'line', 'zone'],
    ['Alder Cross', 'Amber', 2],
    ['Quill Wharf', 'Cobalt', 3],
    ['Saltwick Halt', 'Amber', 5],
    ['Nether Gate', 'Emerald', 2],
];

// The handle API, with the CSV writer that quotes fields for you.
$handle = fopen($path, 'wb');
foreach ($rows as $row) {
    fputcsv($handle, $row, escape: '\\');
}
fclose($handle);

printf("wrote %d bytes to %s%s", filesize($path), $path, PHP_EOL);

// Whole-file helpers, for files small enough to hold in memory.
echo 'first line: ', strtok(file_get_contents($path), "\n"), PHP_EOL;
echo 'lines: ', count(file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES)), PHP_EOL;

// Reading row by row keeps memory flat however large the file is.
$zones = [];
$handle = fopen($path, 'rb');
fgetcsv($handle, escape: '\\'); // skip the header
while (($row = fgetcsv($handle, escape: '\\')) !== false) {
    $zones[] = (int) $row[2];
    if ($row[1] === 'Amber') {
        echo '  Amber: ', $row[0], PHP_EOL;
    }
}
fclose($handle);
printf("average zone %.2f%s", array_sum($zones) / count($zones), PHP_EOL);

// Appending, and locking so two writers cannot interleave.
file_put_contents($path, "Vellin Halt,Slate,4\n", FILE_APPEND | LOCK_EX);
echo 'now ', count(file($path)), ' lines', PHP_EOL;

// Seeking within a handle.
$handle = fopen($path, 'rb');
fseek($handle, 0, SEEK_END);
echo 'size from the handle: ', ftell($handle), PHP_EOL;
rewind($handle);
echo 'first 11 bytes: ', fread($handle, 11), PHP_EOL;
fclose($handle);

// Paths and metadata.
echo 'basename: ', basename($path), ' | extension: ', pathinfo($path, PATHINFO_EXTENSION), PHP_EOL;
echo 'readable: ', var_export(is_readable($path), true), PHP_EOL;
echo 'directory listing: ', implode(', ', array_diff(scandir($directory), ['.', '..'])), PHP_EOL;

// Failures are warnings by default, so check before opening.
if (!file_exists("{$directory}/missing.csv")) {
    echo 'missing.csv is not there, as expected', PHP_EOL;
}

unlink($path);
rmdir($directory);
echo 'cleaned up: ', var_export(!is_dir($directory), true), PHP_EOL;
