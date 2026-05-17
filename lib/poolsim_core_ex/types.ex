defmodule PoolsimCoreEx.WorkloadConfig do
  @moduledoc """
  Input workload used by simulation and evaluation.

  This describes request rate and latency percentiles, with optional raw latency
  samples and an optional step-load profile for burst analysis.
  """

  @enforce_keys [:requests_per_second, :latency_p50_ms, :latency_p95_ms, :latency_p99_ms]
  defstruct [
    :requests_per_second,
    :latency_p50_ms,
    :latency_p95_ms,
    :latency_p99_ms,
    raw_samples_ms: nil,
    step_load_profile: nil
  ]

  @type t :: %__MODULE__{
          requests_per_second: float(),
          latency_p50_ms: float(),
          latency_p95_ms: float(),
          latency_p99_ms: float(),
          raw_samples_ms: [float()] | nil,
          step_load_profile: [PoolsimCoreEx.StepLoadPoint.t()] | nil
        }
end

defmodule PoolsimCoreEx.StepLoadPoint do
  @moduledoc """
  A single traffic step used in a step-load profile.

  `time_s` is the offset from scenario start, and `requests_per_second` is the
  arrival rate at that point.
  """

  @enforce_keys [:time_s, :requests_per_second]
  defstruct [:time_s, :requests_per_second]

  @type t :: %__MODULE__{
          time_s: non_neg_integer(),
          requests_per_second: float()
        }
end

defmodule PoolsimCoreEx.PoolConfig do
  @moduledoc """
  Pool sizing constraints passed to the native engine.

  These fields bound the search space for recommended pool sizes and describe
  the backend connection budget.
  """

  @enforce_keys [:max_server_connections, :connection_overhead_ms, :min_pool_size, :max_pool_size]
  defstruct [
    :max_server_connections,
    :connection_overhead_ms,
    :min_pool_size,
    :max_pool_size,
    idle_timeout_ms: nil
  ]

  @type t :: %__MODULE__{
          max_server_connections: pos_integer(),
          connection_overhead_ms: float(),
          idle_timeout_ms: non_neg_integer() | nil,
          min_pool_size: pos_integer(),
          max_pool_size: pos_integer()
        }
end

defmodule PoolsimCoreEx.SimulationOptions do
  @moduledoc """
  Optional knobs for simulation, queue modeling, and optimization.

  The defaults mirror the defaults exposed by `poolsim-core`.
  """

  defstruct iterations: 10_000,
            seed: nil,
            distribution: :log_normal,
            queue_model: :mmc,
            target_wait_p99_ms: 50.0,
            max_acceptable_rho: 0.85

  @type distribution_model :: :log_normal | :exponential | :empirical | :gamma
  @type queue_model :: :mmc | :mdc

  @type t :: %__MODULE__{
          iterations: pos_integer(),
          seed: non_neg_integer() | nil,
          distribution: distribution_model(),
          queue_model: queue_model(),
          target_wait_p99_ms: float(),
          max_acceptable_rho: float()
        }
end

defmodule PoolsimCoreEx.SensitivityRow do
  @moduledoc """
  Sensitivity result for one candidate pool size.

  Returned by `PoolsimCoreEx.sweep/3` and embedded in
  `PoolsimCoreEx.SimulationReport`.
  """

  defstruct [:pool_size, :utilisation_rho, :mean_queue_wait_ms, :p99_queue_wait_ms, :risk]

  @type risk_level :: :low | :medium | :high | :critical

  @type t :: %__MODULE__{
          pool_size: pos_integer(),
          utilisation_rho: float(),
          mean_queue_wait_ms: float(),
          p99_queue_wait_ms: float(),
          risk: risk_level()
        }
end

defmodule PoolsimCoreEx.StepLoadResult do
  @moduledoc """
  Result row for one step in a step-load analysis.

  These rows appear in `PoolsimCoreEx.SimulationReport.step_load_analysis` when
  a workload includes `step_load_profile`.
  """

  defstruct [:time_s, :requests_per_second, :utilisation_rho, :p99_queue_wait_ms, :saturation]

  @type saturation_level :: :ok | :warning | :critical

  @type t :: %__MODULE__{
          time_s: non_neg_integer(),
          requests_per_second: float(),
          utilisation_rho: float(),
          p99_queue_wait_ms: float(),
          saturation: saturation_level()
        }
end

defmodule PoolsimCoreEx.SimulationReport do
  @moduledoc """
  Full output of `PoolsimCoreEx.simulate/3`.

  Includes the recommended pool size, confidence interval, queue-wait metrics,
  sensitivity rows, optional step-load analysis, and warnings.
  """

  defstruct [
    :optimal_pool_size,
    :confidence_interval,
    :cold_start_min_pool_size,
    :utilisation_rho,
    :mean_queue_wait_ms,
    :p99_queue_wait_ms,
    :saturation,
    sensitivity: [],
    step_load_analysis: [],
    warnings: []
  ]

  @type saturation_level :: :ok | :warning | :critical

  @type t :: %__MODULE__{
          optimal_pool_size: pos_integer(),
          confidence_interval: {pos_integer(), pos_integer()},
          cold_start_min_pool_size: pos_integer(),
          utilisation_rho: float(),
          mean_queue_wait_ms: float(),
          p99_queue_wait_ms: float(),
          saturation: saturation_level(),
          sensitivity: [PoolsimCoreEx.SensitivityRow.t()],
          step_load_analysis: [PoolsimCoreEx.StepLoadResult.t()],
          warnings: [String.t()]
        }
end

defmodule PoolsimCoreEx.EvaluationResult do
  @moduledoc """
  Output of `PoolsimCoreEx.evaluate/3` for a fixed pool size.

  Use this when the pool size is already chosen and only the operating
  characteristics need to be measured.
  """

  defstruct [
    :pool_size,
    :utilisation_rho,
    :mean_queue_wait_ms,
    :p99_queue_wait_ms,
    :saturation,
    warnings: []
  ]

  @type saturation_level :: :ok | :warning | :critical

  @type t :: %__MODULE__{
          pool_size: pos_integer(),
          utilisation_rho: float(),
          mean_queue_wait_ms: float(),
          p99_queue_wait_ms: float(),
          saturation: saturation_level(),
          warnings: [String.t()]
        }
end

defmodule PoolsimCoreEx.Error do
  @moduledoc """
  Structured error returned by the wrapper.

  Errors include a stable code, a human-readable message, and optional details
  forwarded from `poolsim-core`.
  """

  defstruct [:code, :message, :details]

  @type t :: %__MODULE__{
          code: String.t(),
          message: String.t(),
          details: map() | list() | String.t() | number() | boolean() | nil
        }
end
