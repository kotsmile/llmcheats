---
title: WebSocket hub over pub/sub
summary: The per-pod connection map backed by a pub/sub fan-out, encrypted message storage, the wire frames, and the deliberate drop-on-overflow backpressure.
theme: backend
keywords: [websocket, hub, pubsub, subscription, per-user channel, AES-GCM, nonce, ping pong, origin allowlist, send buffer, backpressure, raw broadcast, read loop, normalized pair]
related:
  - backend/http-endpoints-and-middleware.md
  - backend/llm-routing-and-tools.md
  - backend/database-and-migrations.md
---

## Hub structure

The hub holds two maps:

- **connections** — this pod's local WebSocket connections, keyed by user.
- **subscriptions** — one subscription per user channel per pod, shared by all of that user's connections.

Cross-pod delegation goes through a `PubSub` interface implemented over Redis. Every broadcast is published; incoming messages come back through a relay loop that delivers locally.

- Delivery works regardless of which pod the recipient is connected to.
- On a publish failure, local delivery still runs on the current pod, so the local recipient is not lost.
- The subscription is created on the user's **first** connection and closed on the **last** unregister — not per message.

**One channel per user** (`user:<id>`). Do not create a per-conversation or per-room channel: this is a personal stream, not a chat room.

## Encrypted message storage

The persistence layer takes a 16/24/32-byte encryption key; a shorter one makes the constructor fail. Each message is saved with **its own nonce** — no global IV.

Content is stored only encrypted, so the read path decrypts per row. A decrypt error **returns an error** rather than empty content, deliberately: a corrupted row must not be masked.

The key is shared with the model-serving domain by configuration. It is tied to the persistence instance — do not cache it in a package-level variable.

## Normalized pair rows

State about a pair of users (e.g. a closed conversation) is stored as exactly **one** row per pair, keyed by the ordered pair `(LEAST(a,b), GREATEST(a,b))`.

A helper produces the sorted pair and is required in every read and write on that table; joins sort inline with the same expressions.

Never store both `(a,b)` and `(b,a)`, and never search with `OR` — that breaks the conflict-do-nothing upsert and produces duplicates.

## System messages

System messages use the nil UUID as sender. This creates phantom peers in list queries, filtered out by excluding the system id from peer counting.

The correct fix is a migration adding an explicit `is_system` boolean, **not** an outer-query filter and not removing the current filter. Until then the filter is load-bearing.

## Connection handling

- The route is registered on the parent router, outside the request-timeout group, and the handler clears the write deadline. Both are required — see the deadline rules in the HTTP doc.
- The upgrade uses an **origin allowlist from config**. The ingress does not check this: CORS never applies to a WebSocket handshake, so accepting any origin lets a third-party page open an authenticated socket using the session cookie. The allowlist is set per environment and is deliberately narrower than the ingress CORS list. Native clients send no origin header and are always admitted.
- Per-connection send buffer: 256 messages. Subscription channel buffer: 64.

## Wire frames

**Incoming** (client → server):

```json
{ "chat_id": "<uuid>", "content": "...", "file_ids": ["<uuid>"] }
```

A frame with `"type": "ping"` is answered `{"type":"pong"}` and never reaches the service. Browser and React Native WebSocket clients can neither send nor observe protocol-level ping/pong, so this application-level exchange is the only way a half-open socket is detectable.

The pong must go out through the hub's direct-send path — a direct write races the hub's close of the send channel, because the read loop outlives that window.

Invalid JSON or ids are debug-logged and skipped, not closed. Service-level rejections are also debug-logged only; the client confirms a send over REST if it needs certainty.

**Outgoing** (server → client) is serialized from a single outgoing-message struct with a `type` discriminator, ids, content, attachments and a timestamp.

## Stream events are a separate type set

Model-streaming event types are defined in the model-serving domain and are **not** mapped through the chat outgoing-message type. The two sets overlap by string value only — do not mirror new stream types back into the chat entity.

## Backpressure is drop, not block

On send-buffer overflow the message is **dropped with a warning**. This is intentional — blocking on TCP would stall the hub.

For critical events a WebSocket bounce is therefore not sufficient: use a push notification or a client-side state resync.

Do not shrink the send buffer below 64–128; smaller buffers randomly drop system and streaming messages.

## Raw broadcast — the one-way cross-domain contract

Streaming from another domain does **not** go through the chat service and does not write to the messages table; those turns are stored by the producing domain in its own table.

1. The producing domain declares its own broadcaster port.
2. Its infra adapter declares a **narrow** interface — a single method taking a user id and a byte slice.
3. The hub's raw-broadcast method satisfies it.
4. The adapter marshals its event itself; the hub publishes the bytes as-is and never parses or validates the schema.

Neither domain imports the other; the adapter is the only link.

| Change | Impact |
| --- | --- |
| Shape of the stream event | Producing domain + the client parser; the hub is untouched |
| Shape of the outgoing chat message | The client chat parser; the producing domain is unaffected |
| Reusing the pub/sub for another streaming feature | Add a second adapter over the same narrow interface |

Routing streaming through the ordinary send path would double-store the content under the wrong key and make the producer appear as a peer in the conversation list.

## Read/write loop lifecycle

The read and write loops run in parallel; a deferred cancel guarantees both terminate on handler exit. Writer shutdown is triggered by closing the send channel on graceful shutdown, and the write loop exits on the closed-channel signal.

The subscription's read loop closes its channel when the upstream channel terminates, and the relay loop is a plain range over it. **Do not add a second select on context cancellation in the relay loop** — channel closure is the only stop signal, and a double exit path leaks goroutines.

## Known performance debt

The conversation-list query does an N+1 lookup per peer. Tolerable at low traffic with short pages; on growth, join or batch-fetch.
