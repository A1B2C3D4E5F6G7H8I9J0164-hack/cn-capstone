# Mac 4 Backend Server B and Test Client

## Team Member
Saumya Mishra

## Role
Backend Application Server Instance B + Test Client

## Network Configuration
- Hostname: `cn-backend-b`
- Assigned IP: `10.7.7.25`
- Active Interface: `en0`
- Service Port: `3002` (TCP)
- Socket Binding: `0.0.0.0:3002` (LAN accessible)

## Endpoints
- `GET /`: Returns JSON payload with backend identifier and status.
- `GET /api/status`: Returns JSON status object for upstream health checks.

## Response Headers
- `X-Backend: B`
- `ETag: "B-v1"`
- `Cache-Control: max-age=60`
- `Content-Type: application/json`

## Execution Instructions
Start Backend Server B:
```bash
python3 server.py
```

Run in background with nohup:
```bash
nohup python3 server.py > backend-b.log 2>&1 &
```

Stop the server:
```bash
kill $(lsof -t -i :3002)
```

## Local Verification
```bash
# Verify port listening on all interfaces
lsof -nP -iTCP:3002 -sTCP:LISTEN

# Test endpoint directly
curl -i http://localhost:3002/api/status
curl -i http://10.7.7.25:3002/api/status
```

## Test Client Role
Mac 4 also serves as an evaluation client workstation:
1. Configure DNS to point to Mac 1:
   ```bash
   sudo networksetup -setdnsservers Wi-Fi 10.7.x.x
   ```
2. Import trusted root certificate:
   ```bash
   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain server.crt
   ```
3. Execute end-to-end HTTPS tests:
   ```bash
   curl -i https://app.cn-capstone.test:8443/api/status
   ```
