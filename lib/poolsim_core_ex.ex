defmodule PoolsimCoreEx do
  @moduledoc """
  Elixir wrapper for the `poolsim-core` Rust crate.

  The wrapper accepts plain maps or the provided structs and returns typed Elixir
  structs with the results from the native simulation engine.
  """

  alias PoolsimCoreEx.{
    Error,
    EvaluationResult,
    Native,
    PoolConfig,
    SensitivityRow,
    SimulationOptions,
    SimulationReport,
    StepLoadResult,
    WorkloadConfig
  }

  @type simulate_result :: {:ok, SimulationReport.t()} | {:error, Error.t()}
  @type evaluate_result :: {:ok, EvaluationResult.t()} | {:error, Error.t()}
  @type sweep_result :: {:ok, [SensitivityRow.t()]} | {:error, Error.t()}

  @doc """
  Runs the full recommendation workflow and returns a `SimulationReport`.
  """
  @spec simulate(
          WorkloadConfig.t() | map(),
          PoolConfig.t() | map(),
          SimulationOptions.t() | map()
        ) ::
          simulate_result()
  def simulate(workload, pool, options \\ %SimulationOptions{}) do
    workload_json = encode_payload(workload)
    pool_json = encode_payload(pool)
    options_json = encode_payload(options)

    case Native.simulate(workload_json, pool_json, options_json) do
      {:ok, json} ->
        {:ok, json |> Jason.decode!(keys: :atoms) |> build_simulation_report()}

      {:error, json} ->
        {:error, json |> Jason.decode!() |> build_error()}
    end
  end

  @doc """
  Evaluates a fixed pool size and returns an `EvaluationResult`.
  """
  @spec evaluate(WorkloadConfig.t() | map(), pos_integer(), SimulationOptions.t() | map()) ::
          evaluate_result()
  def evaluate(workload, pool_size, options \\ %SimulationOptions{}) do
    workload_json = encode_payload(workload)
    options_json = encode_payload(options)

    case Native.evaluate(workload_json, pool_size, options_json) do
      {:ok, json} ->
        {:ok, json |> Jason.decode!(keys: :atoms) |> build_evaluation_result()}

      {:error, json} ->
        {:error, json |> Jason.decode!() |> build_error()}
    end
  end

  @doc """
  Runs a sensitivity sweep across the configured pool-size range.
  """
  @spec sweep(WorkloadConfig.t() | map(), PoolConfig.t() | map(), SimulationOptions.t() | map()) ::
          sweep_result()
  def sweep(workload, pool, options \\ %SimulationOptions{}) do
    workload_json = encode_payload(workload)
    pool_json = encode_payload(pool)
    options_json = encode_payload(options)

    case Native.sweep(workload_json, pool_json, options_json) do
      {:ok, json} ->
        rows =
          json
          |> Jason.decode!(keys: :atoms)
          |> Enum.map(&build_sensitivity_row/1)

        {:ok, rows}

      {:error, json} ->
        {:error, json |> Jason.decode!() |> build_error()}
    end
  end

  defp encode_payload(payload) do
    payload
    |> normalize_term()
    |> Jason.encode!()
  end

  defp normalize_term(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> normalize_term()
  end

  defp normalize_term(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {normalize_key(key), normalize_term(value)}
    end)
  end

  defp normalize_term(list) when is_list(list), do: Enum.map(list, &normalize_term/1)
  defp normalize_term(value) when value in [true, false, nil], do: value
  defp normalize_term(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_term(value), do: value

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: key

  defp build_simulation_report(%{
         optimal_pool_size: optimal_pool_size,
         confidence_interval: [low, high],
         cold_start_min_pool_size: cold_start_min_pool_size,
         utilisation_rho: utilisation_rho,
         mean_queue_wait_ms: mean_queue_wait_ms,
         p99_queue_wait_ms: p99_queue_wait_ms,
         saturation: saturation,
         sensitivity: sensitivity,
         step_load_analysis: step_load_analysis,
         warnings: warnings
       }) do
    %SimulationReport{
      optimal_pool_size: optimal_pool_size,
      confidence_interval: {low, high},
      cold_start_min_pool_size: cold_start_min_pool_size,
      utilisation_rho: utilisation_rho,
      mean_queue_wait_ms: mean_queue_wait_ms,
      p99_queue_wait_ms: p99_queue_wait_ms,
      saturation: enum_atom(saturation),
      sensitivity: Enum.map(sensitivity, &build_sensitivity_row/1),
      step_load_analysis: Enum.map(step_load_analysis, &build_step_load_result/1),
      warnings: warnings
    }
  end

  defp build_evaluation_result(%{
         pool_size: pool_size,
         utilisation_rho: utilisation_rho,
         mean_queue_wait_ms: mean_queue_wait_ms,
         p99_queue_wait_ms: p99_queue_wait_ms,
         saturation: saturation,
         warnings: warnings
       }) do
    %EvaluationResult{
      pool_size: pool_size,
      utilisation_rho: utilisation_rho,
      mean_queue_wait_ms: mean_queue_wait_ms,
      p99_queue_wait_ms: p99_queue_wait_ms,
      saturation: enum_atom(saturation),
      warnings: warnings
    }
  end

  defp build_sensitivity_row(%{
         pool_size: pool_size,
         utilisation_rho: utilisation_rho,
         mean_queue_wait_ms: mean_queue_wait_ms,
         p99_queue_wait_ms: p99_queue_wait_ms,
         risk: risk
       }) do
    %SensitivityRow{
      pool_size: pool_size,
      utilisation_rho: utilisation_rho,
      mean_queue_wait_ms: mean_queue_wait_ms,
      p99_queue_wait_ms: p99_queue_wait_ms,
      risk: enum_atom(risk)
    }
  end

  defp build_step_load_result(%{
         time_s: time_s,
         requests_per_second: requests_per_second,
         utilisation_rho: utilisation_rho,
         p99_queue_wait_ms: p99_queue_wait_ms,
         saturation: saturation
       }) do
    %StepLoadResult{
      time_s: time_s,
      requests_per_second: requests_per_second,
      utilisation_rho: utilisation_rho,
      p99_queue_wait_ms: p99_queue_wait_ms,
      saturation: enum_atom(saturation)
    }
  end

  defp build_error(%{"code" => code, "message" => message, "details" => details}) do
    %Error{code: code, message: message, details: details}
  end

  defp enum_atom(value) when is_binary(value), do: String.to_atom(value)
  defp enum_atom(value) when is_atom(value), do: value
end
