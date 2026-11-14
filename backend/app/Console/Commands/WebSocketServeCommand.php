<?php

namespace App\Console\Commands;

use GuzzleHttp\Psr7\HttpFactory;
use GuzzleHttp\Psr7\Message as Psr7Message;
use Illuminate\Console\Command;
use Psr\Http\Message\ResponseInterface;
use Ratchet\RFC6455\Handshake\RequestVerifier;
use Ratchet\RFC6455\Handshake\ServerNegotiator;
use Ratchet\RFC6455\Messaging\CloseFrameChecker;
use Ratchet\RFC6455\Messaging\Frame;
use Ratchet\RFC6455\Messaging\MessageBuffer;
use Ratchet\RFC6455\Messaging\MessageInterface;
use React\EventLoop\Loop;
use React\Http\HttpServer;
use React\Http\Message\Response;
use React\Socket\ConnectionInterface;
use React\Socket\SocketServer;

class WebSocketServeCommand extends Command
{
    protected $signature = 'websocket:serve {--host=0.0.0.0} {--port=8080} {--internal-port=8081}';
    protected $description = 'Run the LifeRoute Pusher/Reverb-compatible PHP WebSocket server';

    /** @var array<int, array{conn: ConnectionInterface, channels: array<string, bool>, upgraded: bool, buffer: string, wsBuffer: ?MessageBuffer}> */
    private array $clients = [];

    public function handle(): int
    {
        $host = (string) $this->option('host');
        $port = (int) $this->option('port');
        $internalPort = (int) $this->option('internal-port');

        $loop = Loop::get();
        $negotiator = new ServerNegotiator(new RequestVerifier(), new HttpFactory(), false);
        $closeChecker = new CloseFrameChecker();

        $wsSocket = new SocketServer("{$host}:{$port}", [], $loop);
        $wsSocket->on('connection', function (ConnectionInterface $conn) use ($negotiator, $closeChecker) {
            $id = spl_object_id($conn);
            $this->clients[$id] = [
                'conn' => $conn,
                'channels' => [],
                'upgraded' => false,
                'buffer' => '',
                'wsBuffer' => null,
            ];

            $conn->on('data', function (string $chunk) use ($id, $conn, $negotiator, $closeChecker) {
                if (!isset($this->clients[$id])) {
                    return;
                }

                if ($this->clients[$id]['upgraded']) {
                    $this->clients[$id]['wsBuffer']->onData($chunk);
                    return;
                }

                $this->clients[$id]['buffer'] .= $chunk;
                $headerEnd = strpos($this->clients[$id]['buffer'], "\r\n\r\n");
                if ($headerEnd === false) {
                    return;
                }

                $rawHeaders = substr($this->clients[$id]['buffer'], 0, $headerEnd + 4);
                $leftover = substr($this->clients[$id]['buffer'], $headerEnd + 4);
                $this->clients[$id]['buffer'] = '';

                try {
                    $request = Psr7Message::parseRequest($rawHeaders);
                    /** @var ResponseInterface $response */
                    $response = $negotiator->handshake($request);
                    $conn->write(Psr7Message::toString($response));

                    if ($response->getStatusCode() !== 101) {
                        $conn->end();
                        return;
                    }
                } catch (\Throwable $e) {
                    $conn->end();
                    return;
                }

                $wsBuffer = new MessageBuffer(
                    $closeChecker,
                    function (MessageInterface $msg) use ($id) {
                        $this->handleClientMessage($id, $msg->getPayload());
                    },
                    function (Frame $frame) use ($id, $conn) {
                        if ($frame->getOpcode() === Frame::OP_PING) {
                            $pong = new Frame($frame->getPayload(), true, Frame::OP_PONG);
                            $conn->write($pong->getContents());
                        } elseif ($frame->getOpcode() === Frame::OP_CLOSE) {
                            $conn->end();
                        }
                    },
                    true
                );

                $this->clients[$id]['upgraded'] = true;
                $this->clients[$id]['wsBuffer'] = $wsBuffer;

                $this->info('WebSocket client connected (Total: '.$this->upgradedClientCount().')');

                $this->sendToClient($id, [
                    'event' => 'pusher:connection_established',
                    'data' => json_encode([
                        'socket_id' => ((int) (microtime(true) * 1000)).'.'.random_int(1000, 9999),
                        'activity_timeout' => 120,
                    ]),
                ]);

                if ($leftover !== '') {
                    $wsBuffer->onData($leftover);
                }
            });

            $conn->on('close', function () use ($id) {
                $wasUpgraded = $this->clients[$id]['upgraded'] ?? false;
                unset($this->clients[$id]);
                if ($wasUpgraded) {
                    $this->info('WebSocket client disconnected (Total: '.$this->upgradedClientCount().')');
                }
            });
        });

        $internalHttp = new HttpServer(function (\Psr\Http\Message\ServerRequestInterface $request) {
            $path = $request->getUri()->getPath();
            if ($path === '/stats') {
                return Response::json([
                    'connected_ws_clients' => $this->upgradedClientCount(),
                ]);
            }

            if ($path === '/broadcast' && $request->getMethod() === 'POST') {
                $body = json_decode((string) $request->getBody(), true) ?? [];
                $channels = $body['channels'] ?? [];
                $event = (string) ($body['event'] ?? '');
                $payload = $body['payload'] ?? [];

                if ($event !== '' && !empty($channels)) {
                    $this->broadcastEvent((array) $channels, $event, (array) $payload);
                }

                return Response::json(['status' => 'ok']);
            }

            return Response::json(['status' => 'not_found'], 404);
        });

        $internalSocket = new SocketServer("127.0.0.1:{$internalPort}", [], $loop);
        $internalHttp->listen($internalSocket);

        $this->info("LifeRoute PHP WebSocket Server listening on ws://{$host}:{$port}");
        $this->info("Internal broadcast bridge listening on http://127.0.0.1:{$internalPort}");

        $loop->run();

        return self::SUCCESS;
    }

    private function handleClientMessage(int $clientId, string $rawPayload): void
    {
        $data = json_decode($rawPayload, true);
        if (!is_array($data)) {
            return;
        }

        $event = $data['event'] ?? '';
        if ($event === 'pusher:subscribe' || $event === 'subscribe') {
            $channel = $data['data']['channel'] ?? ($data['channel'] ?? null);
            if (is_string($channel) && $channel !== '' && isset($this->clients[$clientId])) {
                $this->clients[$clientId]['channels'][$channel] = true;
                $this->line("Client subscribed to channel: {$channel}");
                $this->sendToClient($clientId, [
                    'event' => 'pusher_internal:subscription_succeeded',
                    'channel' => $channel,
                    'data' => '{}',
                ]);
            }
        } elseif ($event === 'pusher:ping') {
            $this->sendToClient($clientId, [
                'event' => 'pusher:pong',
                'data' => '{}',
            ]);
        }
    }

    private function broadcastEvent(array $channels, string $eventName, array $payload): void
    {
        $payloadString = json_encode($payload);
        $this->line("[WS Broadcast] Event '{$eventName}' -> ".implode(', ', $channels));

        $notifiedClients = [];
        foreach ($channels as $ch) {
            foreach ($this->clients as $id => $client) {
                if (isset($notifiedClients[$id])) {
                    continue;
                }
                if (!($client['upgraded'] ?? false)) {
                    continue;
                }

                // Broadcast channels reach all; private channels check explicit subscription
                if (!isset($client['channels'][$ch]) && $ch !== 'emergency-broadcasts') {
                    continue;
                }

                $notifiedClients[$id] = true;
                $this->sendToClient($id, [
                    'event' => $eventName,
                    'channel' => $ch,
                    'data' => $payloadString,
                ]);
            }
        }
    }

    private function sendToClient(int $clientId, array $data): void
    {
        if (!isset($this->clients[$clientId])) {
            return;
        }
        $json = json_encode($data);
        if ($json === false) {
            return;
        }
        $frame = new Frame($json, true, Frame::OP_TEXT);
        try {
            $this->clients[$clientId]['conn']->write($frame->getContents());
        } catch (\Throwable $e) {
            // Socket already closed or reset by peer
        }
    }

    private function upgradedClientCount(): int
    {
        $count = 0;
        foreach ($this->clients as $client) {
            if ($client['upgraded'] ?? false) {
                $count++;
            }
        }

        return $count;
    }
}
