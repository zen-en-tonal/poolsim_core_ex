use poolsim_core::{
    self,
    error::PoolsimError,
    types::{
        DistributionModel, EvaluationResult, PoolConfig, QueueModel, RiskLevel, SaturationLevel,
        SensitivityRow, SimulationOptions, SimulationReport, StepLoadPoint, StepLoadResult,
        WorkloadConfig,
    },
};
use serde::{de::DeserializeOwned, Deserialize, Serialize};

rustler::atoms! {
    ok,
    error
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
enum ApiDistributionModel {
    LogNormal,
    Exponential,
    Empirical,
    Gamma,
}

impl From<ApiDistributionModel> for DistributionModel {
    fn from(value: ApiDistributionModel) -> Self {
        match value {
            ApiDistributionModel::LogNormal => Self::LogNormal,
            ApiDistributionModel::Exponential => Self::Exponential,
            ApiDistributionModel::Empirical => Self::Empirical,
            ApiDistributionModel::Gamma => Self::Gamma,
        }
    }
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
enum ApiQueueModel {
    Mmc,
    Mdc,
}

impl From<ApiQueueModel> for QueueModel {
    fn from(value: ApiQueueModel) -> Self {
        match value {
            ApiQueueModel::Mmc => Self::MMC,
            ApiQueueModel::Mdc => Self::MDC,
        }
    }
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
enum ApiRiskLevel {
    Low,
    Medium,
    High,
    Critical,
}

impl From<RiskLevel> for ApiRiskLevel {
    fn from(value: RiskLevel) -> Self {
        match value {
            RiskLevel::Low => Self::Low,
            RiskLevel::Medium => Self::Medium,
            RiskLevel::High => Self::High,
            RiskLevel::Critical => Self::Critical,
        }
    }
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
enum ApiSaturationLevel {
    Ok,
    Warning,
    Critical,
}

impl From<SaturationLevel> for ApiSaturationLevel {
    fn from(value: SaturationLevel) -> Self {
        match value {
            SaturationLevel::Ok => Self::Ok,
            SaturationLevel::Warning => Self::Warning,
            SaturationLevel::Critical => Self::Critical,
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct ApiStepLoadPoint {
    time_s: u32,
    requests_per_second: f64,
}

impl From<ApiStepLoadPoint> for StepLoadPoint {
    fn from(value: ApiStepLoadPoint) -> Self {
        Self {
            time_s: value.time_s,
            requests_per_second: value.requests_per_second,
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct ApiWorkloadConfig {
    requests_per_second: f64,
    latency_p50_ms: f64,
    latency_p95_ms: f64,
    latency_p99_ms: f64,
    raw_samples_ms: Option<Vec<f64>>,
    step_load_profile: Option<Vec<ApiStepLoadPoint>>,
}

impl From<ApiWorkloadConfig> for WorkloadConfig {
    fn from(value: ApiWorkloadConfig) -> Self {
        Self {
            requests_per_second: value.requests_per_second,
            latency_p50_ms: value.latency_p50_ms,
            latency_p95_ms: value.latency_p95_ms,
            latency_p99_ms: value.latency_p99_ms,
            raw_samples_ms: value.raw_samples_ms,
            step_load_profile: value
                .step_load_profile
                .map(|profile| profile.into_iter().map(Into::into).collect()),
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct ApiPoolConfig {
    max_server_connections: u32,
    connection_overhead_ms: f64,
    idle_timeout_ms: Option<u64>,
    min_pool_size: u32,
    max_pool_size: u32,
}

impl From<ApiPoolConfig> for PoolConfig {
    fn from(value: ApiPoolConfig) -> Self {
        Self {
            max_server_connections: value.max_server_connections,
            connection_overhead_ms: value.connection_overhead_ms,
            idle_timeout_ms: value.idle_timeout_ms,
            min_pool_size: value.min_pool_size,
            max_pool_size: value.max_pool_size,
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct ApiSimulationOptions {
    iterations: u32,
    seed: Option<u64>,
    distribution: ApiDistributionModel,
    queue_model: ApiQueueModel,
    target_wait_p99_ms: f64,
    max_acceptable_rho: f64,
}

impl From<ApiSimulationOptions> for SimulationOptions {
    fn from(value: ApiSimulationOptions) -> Self {
        Self {
            iterations: value.iterations,
            seed: value.seed,
            distribution: value.distribution.into(),
            queue_model: value.queue_model.into(),
            target_wait_p99_ms: value.target_wait_p99_ms,
            max_acceptable_rho: value.max_acceptable_rho,
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct ApiSensitivityRow {
    pool_size: u32,
    utilisation_rho: f64,
    mean_queue_wait_ms: f64,
    p99_queue_wait_ms: f64,
    risk: ApiRiskLevel,
}

impl From<SensitivityRow> for ApiSensitivityRow {
    fn from(value: SensitivityRow) -> Self {
        Self {
            pool_size: value.pool_size,
            utilisation_rho: value.utilisation_rho,
            mean_queue_wait_ms: value.mean_queue_wait_ms,
            p99_queue_wait_ms: value.p99_queue_wait_ms,
            risk: value.risk.into(),
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct ApiStepLoadResult {
    time_s: u32,
    requests_per_second: f64,
    utilisation_rho: f64,
    p99_queue_wait_ms: f64,
    saturation: ApiSaturationLevel,
}

impl From<StepLoadResult> for ApiStepLoadResult {
    fn from(value: StepLoadResult) -> Self {
        Self {
            time_s: value.time_s,
            requests_per_second: value.requests_per_second,
            utilisation_rho: value.utilisation_rho,
            p99_queue_wait_ms: value.p99_queue_wait_ms,
            saturation: value.saturation.into(),
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct ApiSimulationReport {
    optimal_pool_size: u32,
    confidence_interval: (u32, u32),
    cold_start_min_pool_size: u32,
    utilisation_rho: f64,
    mean_queue_wait_ms: f64,
    p99_queue_wait_ms: f64,
    saturation: ApiSaturationLevel,
    sensitivity: Vec<ApiSensitivityRow>,
    step_load_analysis: Vec<ApiStepLoadResult>,
    warnings: Vec<String>,
}

impl From<SimulationReport> for ApiSimulationReport {
    fn from(value: SimulationReport) -> Self {
        Self {
            optimal_pool_size: value.optimal_pool_size,
            confidence_interval: value.confidence_interval,
            cold_start_min_pool_size: value.cold_start_min_pool_size,
            utilisation_rho: value.utilisation_rho,
            mean_queue_wait_ms: value.mean_queue_wait_ms,
            p99_queue_wait_ms: value.p99_queue_wait_ms,
            saturation: value.saturation.into(),
            sensitivity: value.sensitivity.into_iter().map(Into::into).collect(),
            step_load_analysis: value
                .step_load_analysis
                .into_iter()
                .map(Into::into)
                .collect(),
            warnings: value.warnings,
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct ApiEvaluationResult {
    pool_size: u32,
    utilisation_rho: f64,
    mean_queue_wait_ms: f64,
    p99_queue_wait_ms: f64,
    saturation: ApiSaturationLevel,
    warnings: Vec<String>,
}

impl From<EvaluationResult> for ApiEvaluationResult {
    fn from(value: EvaluationResult) -> Self {
        Self {
            pool_size: value.pool_size,
            utilisation_rho: value.utilisation_rho,
            mean_queue_wait_ms: value.mean_queue_wait_ms,
            p99_queue_wait_ms: value.p99_queue_wait_ms,
            saturation: value.saturation.into(),
            warnings: value.warnings,
        }
    }
}

#[derive(Debug, Serialize)]
struct ApiError {
    code: String,
    message: String,
    details: Option<serde_json::Value>,
}

impl From<PoolsimError> for ApiError {
    fn from(value: PoolsimError) -> Self {
        Self {
            code: value.code().to_string(),
            message: value.to_string(),
            details: value.details().cloned(),
        }
    }
}

impl ApiError {
    fn invalid_argument(message: impl Into<String>) -> Self {
        Self {
            code: "INVALID_ARGUMENT".to_string(),
            message: message.into(),
            details: None,
        }
    }
}

#[rustler::nif]
fn simulate(
    workload_json: String,
    pool_json: String,
    options_json: String,
) -> (rustler::Atom, String) {
    match simulate_impl(&workload_json, &pool_json, &options_json) {
        Ok(json) => (ok(), json),
        Err(api_error) => (
            error(),
            encode_json(&api_error).expect("encode error payload"),
        ),
    }
}

#[rustler::nif]
fn evaluate(
    workload_json: String,
    pool_size: u32,
    options_json: String,
) -> (rustler::Atom, String) {
    match evaluate_impl(&workload_json, pool_size, &options_json) {
        Ok(json) => (ok(), json),
        Err(api_error) => (
            error(),
            encode_json(&api_error).expect("encode error payload"),
        ),
    }
}

#[rustler::nif]
fn sweep(
    workload_json: String,
    pool_json: String,
    options_json: String,
) -> (rustler::Atom, String) {
    match sweep_impl(&workload_json, &pool_json, &options_json) {
        Ok(json) => (ok(), json),
        Err(api_error) => (
            error(),
            encode_json(&api_error).expect("encode error payload"),
        ),
    }
}

fn simulate_impl(
    workload_json: &str,
    pool_json: &str,
    options_json: &str,
) -> Result<String, ApiError> {
    let workload: ApiWorkloadConfig = decode_json(workload_json)?;
    let pool: ApiPoolConfig = decode_json(pool_json)?;
    let options: ApiSimulationOptions = decode_json(options_json)?;

    let report = poolsim_core::simulate(&workload.into(), &pool.into(), &options.into())
        .map_err(ApiError::from)?;

    encode_json(&ApiSimulationReport::from(report))
}

fn evaluate_impl(
    workload_json: &str,
    pool_size: u32,
    options_json: &str,
) -> Result<String, ApiError> {
    let workload: ApiWorkloadConfig = decode_json(workload_json)?;
    let options: ApiSimulationOptions = decode_json(options_json)?;

    let result = poolsim_core::evaluate(&workload.into(), pool_size, &options.into())
        .map_err(ApiError::from)?;

    encode_json(&ApiEvaluationResult::from(result))
}

fn sweep_impl(
    workload_json: &str,
    pool_json: &str,
    options_json: &str,
) -> Result<String, ApiError> {
    let workload: ApiWorkloadConfig = decode_json(workload_json)?;
    let pool: ApiPoolConfig = decode_json(pool_json)?;
    let options: ApiSimulationOptions = decode_json(options_json)?;

    let rows = poolsim_core::sweep_with_options(&workload.into(), &pool.into(), &options.into())
        .map_err(ApiError::from)?;

    let rows: Vec<ApiSensitivityRow> = rows.into_iter().map(Into::into).collect();
    encode_json(&rows)
}

fn decode_json<T: DeserializeOwned>(input: &str) -> Result<T, ApiError> {
    serde_json::from_str(input).map_err(|err| ApiError::invalid_argument(err.to_string()))
}

fn encode_json<T: Serialize>(value: &T) -> Result<String, ApiError> {
    serde_json::to_string(value).map_err(|err| ApiError::invalid_argument(err.to_string()))
}

rustler::init!("Elixir.PoolsimCoreEx.Native");
