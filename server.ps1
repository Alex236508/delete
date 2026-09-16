$port = 5500

$scriptPath = $MyInvocation.InvocationName

if ($PSCommandPath) {
    $baseDir = Split-Path -Parent $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    $baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    $baseDir = Split-Path -Parent $scriptPath
}

Write-Host "Serving folder: $baseDir"

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
$listener.Start()

Write-Host "Server running at http://localhost:$port"
Start-Process "http://localhost:$port"

function Get-ContentType($path) {
    switch -Regex ($path) {
        "\.html$" { "text/html; charset=utf-8" }
        "\.css$" { "text/css; charset=utf-8" }
        "\.js$" { "application/javascript; charset=utf-8" }
        "\.ico$" { "image/x-icon" }
        default { "text/plain; charset=utf-8" }
    }
}

while ($true) {

    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()

    $buffer = New-Object byte[] 8192
    $bytesRead = $stream.Read($buffer, 0, $buffer.Length)

    if ($bytesRead -le 0) {
        $client.Close()
        continue
    }

    $request = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead)

    $path = "/"

    if ($request -match "^GET\s+([^\s]+)") {
        $path = $matches[1]
    }

    $path = $path.Split('?')[0]

    if ($path -eq "/") {
        $path = "/index.html"
    }

    $relativePath = $path.TrimStart("/")
    $filePath = Join-Path $baseDir $relativePath

    Write-Host "Request: $path -> $filePath"

    if (Test-Path $filePath) {

        $contentBytes = [System.IO.File]::ReadAllBytes($filePath)
        $type = Get-ContentType $filePath

        $header =
        "HTTP/1.1 200 OK`r`n" +
        "Content-Type: $type`r`n" +
        "Content-Length: $($contentBytes.Length)`r`n" +
        "Connection: close`r`n`r`n"

        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($header)

        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($contentBytes, 0, $contentBytes.Length)
    }
    else {

        $msg = "404 Not Found: $path"

        $header =
        "HTTP/1.1 404 Not Found`r`n" +
        "Content-Type: text/plain; charset=utf-8`r`n`r`n"

        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($header + $msg)

        $stream.Write($headerBytes, 0, $headerBytes.Length)
    }

    $client.Close()
}
