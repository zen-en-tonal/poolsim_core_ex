defmodule PoolsimCoreEx.Native do
  @moduledoc false

  use Rustler, otp_app: :poolsim_core_ex, crate: "poolsim_core"

  def simulate(_workload_json, _pool_json, _options_json), do: :erlang.nif_error(:nif_not_loaded)
  def evaluate(_workload_json, _pool_size, _options_json), do: :erlang.nif_error(:nif_not_loaded)
  def sweep(_workload_json, _pool_json, _options_json), do: :erlang.nif_error(:nif_not_loaded)
end
