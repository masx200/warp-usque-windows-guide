for (; ; ) {
    curl -x socks5://127.0.0.1:1080 https://api.ip.sb/geoip -v https://ipv6.ipleak.net/?mode=json --doh-url https://pngwczx94z.cloudflare-gateway.com/dns-query -H "user-agent:Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36" -U biiacuuruavimks9d4cn:biiacuuruavimks9d4cn   https://ipv6-check-perf.radar.cloudflare.com/ | jq


    start-sleep 10

    curl -x socks5://127.0.0.1:1080 https://api-ipv6.ip.sb/cdn-cgi/trace  -v  --doh-url https://pngwczx94z.cloudflare-gateway.com/dns-query -H "user-agent:Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36" -U biiacuuruavimks9d4cn:biiacuuruavimks9d4cn https://www.cloudflare.com/cdn-cgi/trace  


    start-sleep 10
}