#!/usr/bin/env node
/**
 * Inject test events into the running Tikora relay — no dependencies.
 * Uses Node's built-in global WebSocket (Node 22+).
 *
 *   node tools/inject.cjs                 # default roster + a few gifts
 *   node tools/inject.cjs alice bob       # custom viewers (comments)
 *
 * The relay broadcasts debug events to every client, so the game reacts
 * exactly as it would to real viewers. Prefer the name:
 *   DEBUG  ->  debug:event / debug:gift   (relay "dev only" channel)
 */
const url = process.env.TIKORA_RELAY_URL || 'ws://127.0.0.1:27016/';
const ws = new WebSocket(url);

const send = (o) => { try { ws.send(JSON.stringify(o)); } catch (e) { /* ignore */ } };
const chat = (u, m = '!join') => send({ type: 'debug:event', data: { type: 'chat', username: u, comment: m } });
const gift = (u, coins, name = 'Rose') => send({ type: 'debug:gift', data: { username: u, giftName: name, coins, count: 1 } });

ws.addEventListener('open', () => {
  console.log('injecting into', url);
  const users = process.argv.slice(2).length ? process.argv.slice(2) : ['alice', 'bob', 'carol', 'dave', 'erin', 'frank'];
  users.forEach((u, i) => setTimeout(() => chat(u), 200 + i * 150));
  setTimeout(() => gift('alice', 1, 'Rose'), 1500);          // small -> boost
  setTimeout(() => gift('bob', 50, 'Finger Heart'), 1900);   // large -> shell
  setTimeout(() => gift('carol', 500, 'Galaxy'), 2300);      // legendary -> chaos
  setTimeout(() => gift('dave', 10, 'Donut'), 2700);         // medium -> banana
  setTimeout(() => { try { ws.close(); } catch (e) {} process.exit(0); }, 4200);
});

ws.addEventListener('error', (e) => console.error('inject error:', e.message || e));
