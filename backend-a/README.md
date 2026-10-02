# Mac 3 Backend Server A

## Team Member
Rachit Gupta

## Role
Backend Application Server Instance A

## Network Configuration
- Hostname: `cn-backend-a`
- Assigned IP: `10.7.22.10`
- Active Interface: `en0`
- Service Port: `3001` (TCP)
- Socket Binding: `0.0.0.0:3001` (LAN accessible)

## Endpoints
- `GET /`: Returns JSON payload with backend identifier and status.
- `GET /api/status`: Returns JSON status object for upstream health checks.

## Response Headers
- `X-Backend: A`
- `ETag: "A-v1"`
- `Cache-Control: max-age=60`
- `Content-Type: application/json`

## Execution Instructions
Start Backend Server A:
```bash
python3 server.py
```

Run in background with nohup:
```bash
nohup python3 server.py > backend-a.log 2>&1 &
```

Stop the server:
```bash
kill $(lsof -t -i :3001)
```

## Local Verification
```bash
# Verify port listening on all interfaces
lsof -nP -iTCP:3001 -sTCP:LISTEN

# Test endpoint directly
curl -i http://localhost:3001/api/status
curl -i http://10.7.22.10:3001/api/status
```
