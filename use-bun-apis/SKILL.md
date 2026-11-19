---
name: use-bun-apis
description: |
  Write and review Bun runtime code using Bun-native APIs instead of Node.js equivalents: Bun.file/Bun.write/Bun.Glob for files, Bun.serve for HTTP and WebSocket servers, Bun.spawn/Bun.spawnSync for child processes, and Bun.$ for shell commands. Trigger when the user mentions Bun, "bun run", Bun.serve, bunfig.toml, or asks which API to use in a Bun codebase, and when reviewing Bun code for Node-isms (fs, http, child_process). Do NOT use for Node-only, Deno, or browser projects, and do not use to debate whether to adopt Bun.
---

# Use Bun APIs

Bun implements the `node:*` modules, so Node code usually runs unchanged. Prefer a Bun-native API when one exists, and fall back to `node:*` for what Bun does not cover.

## Decision table

| Task | Use | Instead of |
|---|---|---|
| Read / write a file | `Bun.file()`, `Bun.write()` | `fs.readFile`, `fs.writeFile` |
| Match paths by pattern | `Bun.Glob` | hand-rolled `readdir` recursion |
| Create / remove directories | `node:fs/promises` | (no Bun equivalent) |
| HTTP server | `Bun.serve()` | `node:http` |
| WebSocket server | `Bun.serve({ websocket })` | `node:http` + `ws` |
| Run a known binary | `Bun.spawn()` / `Bun.spawnSync()` | `child_process.spawn` |
| Run a pipeline or interpolated command | `Bun.$` | `child_process.exec` |

## Rules

1. Read and write files with `Bun.file()` and `Bun.write()`. They return the file handle and byte count directly, so the common single-shot case needs no callback plumbing.
2. Use `node:fs` for what the Bun file API does not cover, such as `mkdir`, `rm`, `rename`, and `chmod`. Those are directory and metadata operations with no Bun-native equivalent.
3. Match paths with `Bun.Glob` instead of walking directories by hand. It handles the pattern matching and the async iteration in one call.
4. Start servers with `Bun.serve()`. Put static paths, parameters, and wildcards in `routes` so matching happens before `fetch` runs.
5. Serve WebSockets from the same `Bun.serve()` instance via its `websocket` option. A second server on another port doubles the connection bookkeeping for no benefit.
6. Start child processes with `Bun.spawn()` in servers and apps, and `Bun.spawnSync()` in command-line tools. The async form does not block the event loop, which matters when the process is serving requests.
7. Use `Bun.$` when the command genuinely needs a shell (pipes, redirection, glob expansion). Use `Bun.spawn()` with an argv array for a fixed command, so arguments are passed literally instead of through shell parsing.
8. Reach for `node:*` modules when no Bun API fits. Bun implements them, so Node-shaped code stays correct instead of being rewritten by hand.

## Files

```ts
const bytes = await Bun.write("./out.txt", "Lorem ipsum"); // bytes written

const text = await Bun.file("./out.txt").text();
const exists = await Bun.file("./out.txt").exists();
```

Stream large files instead of building one string in memory:

```ts
const writer = Bun.file("./big.log").writer();
writer.write("chunk\n");
writer.end(); // flushes and closes; the process stays alive until this runs
```

`Bun.file()` takes a string path, a numeric file descriptor, or a `file://` URL. It does not accept another `BunFile`. Relative paths resolve against the current working directory. To delete a file, use `await Bun.file("./out.txt").delete()`.

```ts
import { readdir } from "node:fs/promises";
const files = await readdir(import.meta.dir); // import.meta.dir is Bun-specific
```

## Glob

```ts
import { Glob } from "bun";

const glob = new Glob("**/*.ts");
for await (const file of glob.scan(".")) {
  console.log(file);
}
```

`glob.scan(root)` is async and `glob.scanSync(root)` is the blocking counterpart. `glob.match(path)` returns a boolean and is already synchronous.

## HTTP server

```ts
const server = Bun.serve({
  routes: {
    "/users/:id": req => new Response(`Hello User ${req.params.id}!`),
    "/api/posts": {
      GET: () => Response.json({ posts: [] }),
      POST: async req => Response.json(await req.json(), { status: 201 }),
    },
    "/favicon.ico": Bun.file("./favicon.ico"),
  },
  fetch(req) {
    return new Response("Not Found", { status: 404 });
  },
});

console.log(server.url.href); // http://localhost:3000/
```

- Put static paths, parameters and wildcards in `routes`.
- Use `fetch` for unmatched requests.
- A route value may be a `Response`, a handler, a method map, or a `BunFile`.
- `routes` requires Bun v1.2.3+; on older versions keep every route inside `fetch`.
- `server.port` and `server.url` expose the bound address. The port defaults to `$BUN_PORT`, `$PORT`, or `$NODE_PORT`, otherwise `3000`. Pass `port: 0` to get a random free port.
- `await server.stop()` drains in-flight requests; `await server.stop(true)` closes active connections immediately.
- Call `server.reload()` to update handlers without a restart. It updates only `fetch`, `error`, `routes` and `websocket` — not `port` or `hostname`.

```ts
server.reload({
  routes: {
    "/api/version": () => Response.json({ version: "2.0.0" }),
  },
});
```

During development, `bun --hot server.ts` reloads the server on file change without restarting the process, which keeps the listening socket open.

## WebSockets

```ts
Bun.serve({
  fetch(req, server) {
    if (server.upgrade(req)) return undefined; // do not return a Response
    return new Response("Upgrade failed", { status: 500 });
  },
  websocket: {
    message(ws, message) {
      ws.send(message); // echo back
    },
  },
});
```

- `server.upgrade(req)` returns a boolean; on success the handler must return `undefined`, not a `Response`.
- `ws.send()` accepts strings, `ArrayBuffer`, typed arrays, and `Blob`.
- `server.upgrade(req, { data })` attaches data that handlers read back as `ws.data`.

## Child processes

```ts
const proc = Bun.spawn(["bun", "--version"], { stderr: "pipe" });
const text = await proc.stdout.text();
const err = await proc.stderr.text();
const code = await proc.exited; // resolves with the exit code
```

- `stdout` is piped by default.
- `stderr` is inherited by default. `proc.stderr` is `undefined` until you set `"pipe"`.
- `stdin` gets no input by default. Pass `"pipe"` to write to it.
- `await proc.exited` resolves with the exit code; `proc.exitCode` and `proc.signalCode` are also available.

`Bun.spawnSync()` is blocking and returns Buffers rather than streams, and has no `exited` promise:

```ts
const proc = Bun.spawnSync(["echo", "hello"]);
console.log(proc.stdout.toString()); // "hello\n"
console.log(proc.success); // boolean
```

For process-to-process messaging, `Bun.spawn({ ipc })` gives a direct channel. The default `advanced` serialization works between Bun processes; set `serialization: "json"` to exchange messages with a Node.js child that uses `process.send()` / `process.on("message")`.

## Shell commands

```ts
import { $ } from "bun";

const version = await $`bun --version`.text();
const data = await $`some-tool --json`.json();
```

- `.text()` and `.json()` capture output and imply `.quiet()`.
- A non-zero exit throws a `ShellError` carrying `exitCode`, `stdout`, and `stderr`. Use `.nothrow()` and check `exitCode` yourself when a failure is expected.
- Interpolated values are escaped and passed as literal arguments, so user input cannot inject shell metacharacters.
- `{ raw: "..." }` bypasses that escaping. Use it only for strings you already trust.

## References

- File I/O: https://bun.com/docs/runtime/file-io
- Glob: https://bun.com/docs/runtime/glob
- Server: https://bun.com/docs/runtime/http/server
- Routing: https://bun.com/docs/runtime/http/routing
- WebSockets: https://bun.com/docs/runtime/http/websockets
- Spawn: https://bun.com/docs/runtime/child-process
- Shell: https://bun.com/docs/runtime/shell
- Watch mode: https://bun.com/docs/runtime/watch-mode
- Node.js compatibility: https://bun.com/docs/runtime/nodejs-compat
