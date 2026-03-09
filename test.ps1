# 定义需要测试的端口列表
 $ports = 1080, 1081, 1082, 1083

for (; ; ) {
    # 循环遍历每一个端口
    foreach ($port in $ports) {
        Write-Host "===== 正在测试端口: $port =====" -ForegroundColor Green
    curl -x  socks5://127.0.0.1:$port  https://api.ip.sb/geoip -v https://ipv6.ipleak.net/?mode=json --doh-url https://pngwczx94z.cloudflare-gateway.com/dns-query -H "user-agent:Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36" -U biiacuuruavimks9d4cn:biiacuuruavimks9d4cn   https://ipv6-check-perf.radar.cloudflare.com/ | jq


    start-sleep 5

    curl -x  socks5://127.0.0.1:$port  https://api-ipv6.ip.sb/cdn-cgi/trace  -v  --doh-url https://pngwczx94z.cloudflare-gateway.com/dns-query -H "user-agent:Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36" -U biiacuuruavimks9d4cn:biiacuuruavimks9d4cn https://www.cloudflare.com/cdn-cgi/trace  https://ipv6.ping0.cc/geo


    start-sleep 5
}

}