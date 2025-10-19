HEALTH METRICS TRACKING

Overview
Adds patient-owned health metrics logging: patients can record timestamped vital measurements (type, value, unit) and query counts/ids. Independent feature with no cross-contract calls.

Technical Implementation
- New data vars: 
ext-metric-id
- New maps: health-metrics, patient-metric-count, patient-metric-index
- New public fn: log-health-metric(metric-type, value, unit)
- New read-only fns: get-health-metric, get-patient-metrics-count, get-patient-metric-id-at

Testing & Validation
•  ? Contract passes clarinet check
•  ? All npm tests successful
•  ? CI/CD pipeline configured
•  ? Clarity v3 compliant with proper error handling
