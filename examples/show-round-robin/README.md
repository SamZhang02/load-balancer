# Round Robin Visualizer

This example hammers an already-running load balancer with parallel `curl`
requests so you can watch the round-robin scheduler cycle through backends.

```bash
examples/show-round-robin/run-example.sh
```

Tip: start `examples/default/run-example.sh` (or your own stack) in another
terminal first so there is a load balancer to target.

The script issues bursts of parallel requests (defaults: five bursts × five
parallel requests) and prints each response, including the backend port. You
should see the port rotate, confirming round-robin behavior.

### Tuning knobs

Use environment variables to tweak the demo without editing files:

- `LB_URL` – absolute URL to hit (defaults to `/hello` on the configured port).
- `LB_TARGET_PORT` – override just the port if the host/path stay the same.
- `PARALLEL_REQUESTS` / `BURSTS` – control how many requests fire per burst.
- `CONFIG_PATH` – point to an alternate load-balancer config when needed.
