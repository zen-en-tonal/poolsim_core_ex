# PoolsimCoreEx

Elixir wrapper around the Rust `poolsim-core` simulation engine.

## Installation

Add the dependency to your `mix.exs`:

```elixir
def deps do
  [
    {:poolsim_core_ex, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
alias PoolsimCoreEx.{PoolConfig, SimulationOptions, WorkloadConfig}

workload = %WorkloadConfig{
  requests_per_second: 220.0,
  latency_p50_ms: 8.0,
  latency_p95_ms: 32.0,
  latency_p99_ms: 85.0
}

pool = %PoolConfig{
  max_server_connections: 120,
  connection_overhead_ms: 2.0,
  min_pool_size: 3,
  max_pool_size: 24
}

options = %SimulationOptions{seed: 7}

{:ok, report} = PoolsimCoreEx.simulate(workload, pool, options)
{:ok, evaluation} = PoolsimCoreEx.evaluate(workload, 10, options)
{:ok, rows} = PoolsimCoreEx.sweep(workload, pool, options)
```

The public API returns:

- `{:ok, %PoolsimCoreEx.SimulationReport{}}`
- `{:ok, %PoolsimCoreEx.EvaluationResult{}}`
- `{:ok, [%PoolsimCoreEx.SensitivityRow{}, ...]}`
- `{:error, %PoolsimCoreEx.Error{}}`
