REM wintun batch

route delete 0.0.0.0
netsh interface ip set address wintun static 172.50.60.70 255.255.255.0 none
timeout /nobreak /t 5
route add 0.0.0.0 mask 0.0.0.0 172.50.60.70

