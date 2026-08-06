$e = [char]27
$lines = @(
    "Code       | Description              | Result",
    "-----------|--------------------------|-----------------------",
    "[0m        | Normal Text              | $($e)[0mSample Text$($e)[0m",
    "[1m        | Bold                     | $($e)[1mSample Text$($e)[0m",
    "[5m        | Blink                    | $($e)[5mSample Text$($e)[0m",
    "[1;5m      | Bold + Blink             | $($e)[1;5mSample Text$($e)[0m",
    "[34m       | Standard Blue            | $($e)[34mSample Text$($e)[0m",
    "[5;34m     | Blink + Standard Blue    | $($e)[5;34mSample Text$($e)[0m",
    "[1;5;94m   | Bold + Blink + Bright    | $($e)[1;5;94mSample Text$($e)[0m"
)
foreach ($line in $lines) {
    Write-Host $line
}
