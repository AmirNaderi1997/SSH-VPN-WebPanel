#!/usr/bin/env python3
"""
VPN Manager - WebSocket SSH Proxy
Allows SSH connections wrapped in WebSockets to bypass DPI firewalls.
Run: /opt/vpn_manager/venv/bin/python /opt/vpn_manager/websocket_proxy.py <port>
"""

import asyncio
import websockets
import base64
import logging
import sys

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

SSH_HOST = "127.0.0.1"
SSH_PORT = 443
WS_PORT = 8880  # Default port (can be overridden by command line argument)

async def ws_to_tcp(websocket, writer):
    try:
        async for message in websocket:
            if isinstance(message, bytes):
                # Binary frame
                writer.write(message)
            else:
                # Text frame (check if base64 encoded or plain text)
                try:
                    # Try to decode base64 first (common in some SSH WS clients)
                    decoded = base64.b64decode(message)
                    writer.write(decoded)
                except Exception:
                    # Fallback to plain text bytes
                    writer.write(message.encode('utf-8'))
            await writer.drain()
    except websockets.exceptions.ConnectionClosed:
        pass
    except Exception as e:
        logging.error(f"Error in ws_to_tcp: {e}")
    finally:
        writer.close()
        try:
            await writer.wait_closed()
        except Exception:
            pass

async def tcp_to_ws(reader, websocket):
    try:
        while True:
            data = await reader.read(4096)
            if not data:
                break
            # Send as binary frame
            await websocket.send(data)
    except websockets.exceptions.ConnectionClosed:
        pass
    except Exception as e:
        logging.error(f"Error in tcp_to_ws: {e}")
    finally:
        try:
            await websocket.close()
        except Exception:
            pass

async def handler(websocket, path):
    logging.info(f"New connection received from {websocket.remote_address}")
    try:
        # Connect to local SSH daemon (running on 443 or 22)
        reader, writer = await asyncio.open_connection(SSH_HOST, SSH_PORT)
    except Exception as e:
        logging.error(f"Failed to connect to local SSH daemon at {SSH_HOST}:{SSH_PORT}: {e}")
        try:
            await websocket.close()
        except Exception:
            pass
        return

    # Run bidirectional piping concurrently
    await asyncio.gather(
        ws_to_tcp(websocket, writer),
        tcp_to_ws(reader, websocket),
        return_exceptions=True
    )
    logging.info(f"Connection with client {websocket.remote_address} closed.")

async def main():
    port = WS_PORT
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            logging.error(f"Invalid port: {sys.argv[1]}. Using default: {WS_PORT}")
            
    logging.info(f"Starting WebSocket SSH Proxy on port {port}...")
    logging.info(f"Forwarding connections to local SSH daemon at {SSH_HOST}:{SSH_PORT}")
    
    async with websockets.serve(handler, "0.0.0.0", port):
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logging.info("Shutting down WebSocket SSH Proxy.")
