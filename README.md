# Load Balancer

This repo is a sandbox I built to learn Go and mess with foundational load-balancing ideas: proxying traffic with `net/http`, round-robin scheduling plus failure tracking.

## Requirements

- Go

## Running the balancer

1. **Configure targets.** Edit `config.yaml` to point `upstream.app.backends` at the HTTP servers you want to balance. The defaults assume the sample backends in this repo.
2. **Start some backends.** Either run your own HTTP services or use the provided sample: `examples/default/run-example.sh` starts five toy backends plus the balancer for you.
3. **Run manually (optional).** To start only the balancer yourself, run `go run ./main.go` from the repo root and hit it with `curl http://localhost:<port>/hello`.

The balancer logs each request and which backend handled it so you can confirm the round-robin behavior and watch the failure tracking kick in when targets disappear.

## Examples

Some scripts were put in `examples/` for trying out different behaviours of the lb

- `examples/default/run-example.sh` — boots five sample Go backends (on ports 8081–8085) and then launches the balancer with `config.yaml`, giving you a full playground stack in one terminal.
- `examples/show-round-robin/run-example.sh` — fires configurable bursts of parallel `curl` requests against a running balancer and prints which backend served each response so you can visualize the scheduler rotation.
- `examples/chaos/run-chaos.sh` — assumes the default example is running, then continuously hits the balancer while randomly killing and respawning sample backends to show how the failure window/timeout logic reacts.
