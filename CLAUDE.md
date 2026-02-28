# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Windows binary distribution of **usque**, an open-source reimplementation of Cloudflare WARP's MASQUE mode. It uses the Connect-IP (RFC 9484) protocol to expose the WARP tunnel as various services (SOCKS5 proxy, HTTP proxy, native tunnel, port forwarding).

This is a **pre-compiled binary package** - not source code. For development, see the upstream repository: https://github.com/Diniboy1123/usque

## Architecture

### Components
- `usque.exe` - Main Go binary implementing MASQUE protocol
- `config.json` - Configuration file containing keys, endpoints, and assigned IPs
- PowerShell scripts - Service management and testing utilities

### Operation Mode
This distribution is configured for **SOCKS5 proxy mode**:
- Binds to `0.0.0.0:1080`
- Uses username/password authentication
- Emulates userspace network stack (cross-platform, no root required)

## Configuration

### config.json Structure
```json
{
  "private_key": "ECDSA P-256 private key (DER, Base64)",
  "endpoint_v4": "Cloudflare WARP IPv4 endpoint",
  "endpoint_v6": "Cloudflare WARP IPv6 endpoint",
  "endpoint_pub_key": "Server public key for authentication",
  "license": "Cloudflare account license token",
  "id": "Device UUID",
  "access_token": "API access token",
  "ipv4": "Internal WARP IPv4 address",
  "ipv6": "Internal WARP IPv6 address"
}
```

## Common Operations

### Registration
```powershell
# Register new device with Cloudflare WARP
.\usque.exe register
```

### Service Management
```powershell
# Install as Windows auto-start service (requires NSSM)
.\install.ps1

# Install monitoring service
.\monitor.ps1

# Manual start
pwsh.exe -f start.ps1

# Stop/uninstall services (requires NSSM)
C:\path\to\nssm.exe stop usque
C:\path\to\nssm.exe remove usque confirm
```

### Proxy Testing
```powershell
# Test SOCKS5 proxy connectivity
.\test.ps1

# Manual curl test
curl -x socks5://127.0.0.1:1080 https://api.ip.sb/geoip
```

## Service Dependencies

This distribution depends on **NSSM (Non-Sucking Service Manager)** being installed at:
```
C:\迅雷下载\nssm-2.24-101-g897c7ad\win64\nssm.exe
```

NSSM is used to run PowerShell scripts as Windows services with automatic restart on failure.

## Key Files

| File | Purpose |
|------|---------|
| [start.ps1](start.ps1) | Starts SOCKS5 proxy with Cloudflare Gateway SNI |
| [register.ps1](register.ps1) | Registers new account (`-a` flag for account creation) |
| [install.ps1](install.ps1) | Installs `usque` service via NSSM |
| [monitor.ps1](monitor.ps1) | Installs monitoring service via NSSM |
| [test.ps1](test.ps1) | Tests proxy connectivity to various endpoints |
| [config.json](config.json) | WARP credentials and configuration |
| [out.log](out.log) | Service stdout output |
| [err.log](err.log) | Service stderr output |

## SOCKS5 Proxy Configuration

The proxy runs with:
- **Bind address**: `0.0.0.0:1080`
- **Username**: `biiacuuruavimks9d4cn`
- **Password**: `biiacuuruavimks9d4cn`
- **DNS servers**: `1.1.1.1`, `8.8.8.8`, `9.9.9.9`, `94.140.14.14`
- **SNI**: `cloudflare-gateway.com` (for ZeroTrust compatibility)

## Logs

Check logs for issues:
- Standard output: [out.log](out.log)
- Error output: [err.log](err.log)

Both logs have timestamps enabled via NSSM configuration.
