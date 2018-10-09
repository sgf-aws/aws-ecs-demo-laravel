<?php

use PhpSafari\Checks\Application\LogLevel;
use PhpSafari\Checks\Application\MaxRatioOf500Responses;
use PhpSafari\Checks\Application\MaxResponseTimeAvg;
use PhpSafari\Checks\Database\DatabaseOnline;
use PhpSafari\Checks\Database\DatabaseUpToDate;
use PhpSafari\Checks\Environment\CorrectEnvironment;
use PhpSafari\Checks\Environment\DebugModeOff;
use PhpSafari\Checks\Filesystem\PathIsWritable;
use PhpSafari\Checks\Queue\QueueIsProcessing;

return [
    'checks' => [
        new DatabaseOnline(),
        new DatabaseUpToDate(),
        //new DebugModeOff(),
        //new LogLevel('error'),
        //new CorrectEnvironment('production'),
        //new QueueIsProcessing(),
        new PathIsWritable(storage_path()),
        new PathIsWritable(storage_path('logs')),
        new PathIsWritable(storage_path('framework/sessions')),
        new PathIsWritable(storage_path('framework/cache')),
        new MaxRatioOf500Responses(1.00),
        new MaxResponseTimeAvg(300),
    ],
    'route'  => [
        'enabled' => true,
    ]
];
