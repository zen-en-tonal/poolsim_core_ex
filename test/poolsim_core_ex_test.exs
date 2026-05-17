defmodule PoolsimCoreExTest do
  use ExUnit.Case

  alias PoolsimCoreEx.{
    Error,
    EvaluationResult,
    PoolConfig,
    SensitivityRow,
    SimulationOptions,
    SimulationReport,
    StepLoadPoint,
    WorkloadConfig
  }

  @workload %WorkloadConfig{
    requests_per_second: 220.0,
    latency_p50_ms: 8.0,
    latency_p95_ms: 32.0,
    latency_p99_ms: 85.0,
    step_load_profile: [
      %StepLoadPoint{time_s: 0, requests_per_second: 220.0},
      %StepLoadPoint{time_s: 30, requests_per_second: 260.0}
    ]
  }

  @pool %PoolConfig{
    max_server_connections: 120,
    connection_overhead_ms: 2.0,
    min_pool_size: 3,
    max_pool_size: 24
  }

  @options %SimulationOptions{
    iterations: 10_000,
    seed: 7,
    distribution: :gamma,
    queue_model: :mmc,
    target_wait_p99_ms: 50.0,
    max_acceptable_rho: 0.85
  }

  test "simulate returns a typed simulation report" do
    assert {:ok, %SimulationReport{} = report} =
             PoolsimCoreEx.simulate(@workload, @pool, @options)

    assert report.optimal_pool_size >= @pool.min_pool_size
    assert report.optimal_pool_size <= @pool.max_pool_size
    assert {low, high} = report.confidence_interval
    assert low <= high
    assert report.saturation in [:ok, :warning, :critical]
    assert Enum.all?(report.sensitivity, &match?(%SensitivityRow{}, &1))
    assert length(report.step_load_analysis) == 2
  end

  test "evaluate returns a typed evaluation result" do
    assert {:ok, %EvaluationResult{} = result} = PoolsimCoreEx.evaluate(@workload, 10, @options)
    assert result.pool_size == 10
    assert result.saturation in [:ok, :warning, :critical]
  end

  test "sweep returns typed sensitivity rows" do
    assert {:ok, rows} = PoolsimCoreEx.sweep(@workload, @pool, @options)
    assert length(rows) == @pool.max_pool_size - @pool.min_pool_size + 1
    assert Enum.all?(rows, &match?(%SensitivityRow{}, &1))
  end

  test "invalid inputs return a structured error" do
    workload = %{@workload | latency_p50_ms: 100.0, latency_p95_ms: 50.0}

    assert {:error, %Error{} = error} = PoolsimCoreEx.simulate(workload, @pool, @options)
    assert error.code == "INVALID_LATENCY_ORDER"
    assert error.details == %{"p50" => 100.0, "p95" => 50.0, "p99" => 85.0}
  end
end
