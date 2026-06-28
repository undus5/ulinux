REM tun2socks batch
REM 10.20.30.40 is your local proxy server IP

%~dp0tun2socks.exe -device wintun -proxy socks5://user:pass@10.20.30.40:1080

