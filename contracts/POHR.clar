;; title: POHR
;; version: 1.0.0
;; summary: Patient-Owned Health Records - Decentralized Healthcare Data Management
;; description: A smart contract enabling patients to own, control, and selectively share their medical data

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-access-expired (err u105))
(define-constant err-access-revoked (err u106))

(define-data-var total-patients uint u0)
(define-data-var total-providers uint u0)
(define-data-var total-records uint u0)
(define-data-var block-counter uint u1)

(define-map patients
  { patient-id: principal }
  {
    name: (string-ascii 100),
    date-of-birth: uint,
    emergency-contact: (string-ascii 100),
    created-at: uint,
    is-active: bool
  }
)

(define-map healthcare-providers
  { provider-id: principal }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    specialty: (string-ascii 50),
    verified: bool,
    created-at: uint
  }
)

(define-map health-records
  { record-id: uint }
  {
    patient-id: principal,
    record-type: (string-ascii 50),
    record-hash: (buff 32),
    created-at: uint,
    last-updated: uint,
    is-encrypted: bool
  }
)

(define-map access-permissions
  { patient-id: principal, provider-id: principal }
  {
    granted-at: uint,
    expires-at: uint,
    access-level: (string-ascii 20),
    is-active: bool,
    permissions: (list 10 (string-ascii 30))
  }
)

(define-map access-logs
  { log-id: uint }
  {
    patient-id: principal,
    provider-id: principal,
    record-id: uint,
    action: (string-ascii 20),
    timestamp: uint
  }
)

(define-map record-versions
  { record-id: uint, version: uint }
  {
    record-hash: (buff 32),
    version-timestamp: uint,
    created-by: principal,
    change-reason: (string-ascii 100),
    is-current: bool
  }
)

(define-map record-version-count
  { record-id: uint }
  { total-versions: uint, current-version: uint }
)

(define-map emergency-access
  { patient-id: principal }
  {
    enabled: bool,
    emergency-contacts: (list 5 principal),
    conditions: (string-ascii 200)
  }
)

(define-data-var next-record-id uint u1)
(define-data-var next-log-id uint u1)

(define-public (register-patient (name (string-ascii 100)) (date-of-birth uint) (emergency-contact (string-ascii 100)))
  (let
    (
      (patient-id tx-sender)
      (current-block (var-get block-counter))
    )
    (asserts! (is-none (map-get? patients { patient-id: patient-id })) err-already-exists)
    (asserts! (> (len name) u0) err-invalid-input)
    (map-set patients
      { patient-id: patient-id }
      {
        name: name,
        date-of-birth: date-of-birth,
        emergency-contact: emergency-contact,
        created-at: current-block,
        is-active: true
      }
    )
    (var-set total-patients (+ (var-get total-patients) u1))
    (var-set block-counter (+ (var-get block-counter) u1))
    (ok patient-id)
  )
)

(define-public (register-provider (name (string-ascii 100)) (license-number (string-ascii 50)) (specialty (string-ascii 50)))
  (let
    (
      (provider-id tx-sender)
      (current-block (var-get block-counter))
    )
    (asserts! (is-none (map-get? healthcare-providers { provider-id: provider-id })) err-already-exists)
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len license-number) u0) err-invalid-input)
    (map-set healthcare-providers
      { provider-id: provider-id }
      {
        name: name,
        license-number: license-number,
        specialty: specialty,
        verified: false,
        created-at: current-block
      }
    )
    (var-set total-providers (+ (var-get total-providers) u1))
    (var-set block-counter (+ (var-get block-counter) u1))
    (ok provider-id)
  )
)

(define-public (verify-provider (provider-id principal))
  (let
    (
      (provider (unwrap! (map-get? healthcare-providers { provider-id: provider-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set healthcare-providers
      { provider-id: provider-id }
      (merge provider { verified: true })
    )
    (ok true)
  )
)

(define-public (add-health-record (record-type (string-ascii 50)) (record-hash (buff 32)) (is-encrypted bool))
  (let
    (
      (patient-id tx-sender)
      (record-id (var-get next-record-id))
      (current-block (var-get block-counter))
    )
    (asserts! (is-some (map-get? patients { patient-id: patient-id })) err-unauthorized)
    (asserts! (> (len record-type) u0) err-invalid-input)
    (map-set health-records
      { record-id: record-id }
      {
        patient-id: patient-id,
        record-type: record-type,
        record-hash: record-hash,
        created-at: current-block,
        last-updated: current-block,
        is-encrypted: is-encrypted
      }
    )
    (map-set record-versions
      { record-id: record-id, version: u1 }
      {
        record-hash: record-hash,
        version-timestamp: current-block,
        created-by: patient-id,
        change-reason: "initial-creation",
        is-current: true
      }
    )
    (map-set record-version-count
      { record-id: record-id }
      { total-versions: u1, current-version: u1 }
    )
    (var-set next-record-id (+ record-id u1))
    (var-set total-records (+ (var-get total-records) u1))
    (var-set block-counter (+ (var-get block-counter) u1))
    (ok record-id)
  )
)

(define-public (grant-access (provider-id principal) (expires-in-blocks uint) (access-level (string-ascii 20)) (permissions (list 10 (string-ascii 30))))
  (let
    (
      (patient-id tx-sender)
      (current-block (var-get block-counter))
      (expires-at (+ current-block expires-in-blocks))
    )
    (asserts! (is-some (map-get? patients { patient-id: patient-id })) err-unauthorized)
    (asserts! (is-some (map-get? healthcare-providers { provider-id: provider-id })) err-not-found)
    (asserts! (> expires-in-blocks u0) err-invalid-input)
    (map-set access-permissions
      { patient-id: patient-id, provider-id: provider-id }
      {
        granted-at: current-block,
        expires-at: expires-at,
        access-level: access-level,
        is-active: true,
        permissions: permissions
      }
    )
    (log-access patient-id provider-id u0 "GRANT_ACCESS")
    (ok true)
  )
)

(define-public (revoke-access (provider-id principal))
  (let
    (
      (patient-id tx-sender)
      (current-access (unwrap! (map-get? access-permissions { patient-id: patient-id, provider-id: provider-id }) err-not-found))
    )
    (asserts! (is-some (map-get? patients { patient-id: patient-id })) err-unauthorized)
    (map-set access-permissions
      { patient-id: patient-id, provider-id: provider-id }
      (merge current-access { is-active: false })
    )
    (log-access patient-id provider-id u0 "REVOKE_ACCESS")
    (ok true)
  )
)

(define-public (access-health-record (patient-id principal) (record-id uint))
  (let
    (
      (provider-id tx-sender)
      (current-block (var-get block-counter))
      (access-info (unwrap! (map-get? access-permissions { patient-id: patient-id, provider-id: provider-id }) err-unauthorized))
      (record (unwrap! (map-get? health-records { record-id: record-id }) err-not-found))
    )
    (asserts! (get verified (unwrap! (map-get? healthcare-providers { provider-id: provider-id }) err-unauthorized)) err-unauthorized)
    (asserts! (get is-active access-info) err-access-revoked)
    (asserts! (< current-block (get expires-at access-info)) err-access-expired)
    (asserts! (is-eq (get patient-id record) patient-id) err-unauthorized)
    (log-access patient-id provider-id record-id "ACCESS_RECORD")
    (ok record)
  )
)

(define-public (update-health-record (record-id uint) (new-record-hash (buff 32)) (change-reason (string-ascii 100)))
  (let
    (
      (patient-id tx-sender)
      (current-block (var-get block-counter))
      (record (unwrap! (map-get? health-records { record-id: record-id }) err-not-found))
      (version-info (unwrap! (map-get? record-version-count { record-id: record-id }) err-not-found))
      (new-version (+ (get current-version version-info) u1))
    )
    (asserts! (is-eq (get patient-id record) patient-id) err-unauthorized)
    (asserts! (> (len change-reason) u0) err-invalid-input)
    (map-set record-versions
      { record-id: record-id, version: (get current-version version-info) }
      (merge (unwrap-panic (map-get? record-versions { record-id: record-id, version: (get current-version version-info) })) { is-current: false })
    )
    (map-set record-versions
      { record-id: record-id, version: new-version }
      {
        record-hash: new-record-hash,
        version-timestamp: current-block,
        created-by: patient-id,
        change-reason: change-reason,
        is-current: true
      }
    )
    (map-set record-version-count
      { record-id: record-id }
      { total-versions: new-version, current-version: new-version }
    )
    (map-set health-records
      { record-id: record-id }
      (merge record { record-hash: new-record-hash, last-updated: current-block })
    )
    (log-access patient-id patient-id record-id "UPDATE_RECORD")
    (var-set block-counter (+ (var-get block-counter) u1))
    (ok new-version)
  )
)

(define-public (set-emergency-access (enabled bool) (emergency-contacts (list 5 principal)) (conditions (string-ascii 200)))
  (let
    (
      (patient-id tx-sender)
    )
    (asserts! (is-some (map-get? patients { patient-id: patient-id })) err-unauthorized)
    (map-set emergency-access
      { patient-id: patient-id }
      {
        enabled: enabled,
        emergency-contacts: emergency-contacts,
        conditions: conditions
      }
    )
    (ok true)
  )
)

(define-public (emergency-access-record (patient-id principal) (record-id uint))
  (let
    (
      (provider-id tx-sender)
      (emergency-info (unwrap! (map-get? emergency-access { patient-id: patient-id }) err-unauthorized))
      (record (unwrap! (map-get? health-records { record-id: record-id }) err-not-found))
    )
    (asserts! (get verified (unwrap! (map-get? healthcare-providers { provider-id: provider-id }) err-unauthorized)) err-unauthorized)
    (asserts! (get enabled emergency-info) err-unauthorized)
    (asserts! (is-eq (get patient-id record) patient-id) err-unauthorized)
    (log-access patient-id provider-id record-id "EMERGENCY_ACCESS")
    (ok record)
  )
)

(define-public (extend-access (provider-id principal) (additional-blocks uint))
  (let
    (
      (patient-id tx-sender)
      (current-access (unwrap! (map-get? access-permissions { patient-id: patient-id, provider-id: provider-id }) err-not-found))
    )
    (asserts! (get is-active current-access) err-access-revoked)
    (asserts! (> additional-blocks u0) err-invalid-input)
    (map-set access-permissions
      { patient-id: patient-id, provider-id: provider-id }
      (merge current-access { expires-at: (+ (get expires-at current-access) additional-blocks) })
    )
    (log-access patient-id provider-id u0 "EXTEND_ACCESS")
    (ok true)
  )
)

(define-public (rollback-record-version (record-id uint) (target-version uint) (rollback-reason (string-ascii 100)))
  (let
    (
      (patient-id tx-sender)
      (current-block (var-get block-counter))
      (record (unwrap! (map-get? health-records { record-id: record-id }) err-not-found))
      (version-info (unwrap! (map-get? record-version-count { record-id: record-id }) err-not-found))
      (target-version-data (unwrap! (map-get? record-versions { record-id: record-id, version: target-version }) err-not-found))
      (new-version (+ (get current-version version-info) u1))
    )
    (asserts! (is-eq (get patient-id record) patient-id) err-unauthorized)
    (asserts! (> target-version u0) err-invalid-input)
    (asserts! (<= target-version (get total-versions version-info)) err-invalid-input)
    (asserts! (> (len rollback-reason) u0) err-invalid-input)
    (map-set record-versions
      { record-id: record-id, version: (get current-version version-info) }
      (merge (unwrap-panic (map-get? record-versions { record-id: record-id, version: (get current-version version-info) })) { is-current: false })
    )
    (map-set record-versions
      { record-id: record-id, version: new-version }
      {
        record-hash: (get record-hash target-version-data),
        version-timestamp: current-block,
        created-by: patient-id,
        change-reason: rollback-reason,
        is-current: true
      }
    )
    (map-set record-version-count
      { record-id: record-id }
      { total-versions: new-version, current-version: new-version }
    )
    (map-set health-records
      { record-id: record-id }
      (merge record { record-hash: (get record-hash target-version-data), last-updated: current-block })
    )
    (log-access patient-id patient-id record-id "ROLLBACK_RECORD")
    (var-set block-counter (+ (var-get block-counter) u1))
    (ok new-version)
  )
)

(define-public (deactivate-patient)
  (let
    (
      (patient-id tx-sender)
      (patient (unwrap! (map-get? patients { patient-id: patient-id }) err-not-found))
    )
    (map-set patients
      { patient-id: patient-id }
      (merge patient { is-active: false })
    )
    (ok true)
  )
)

(define-read-only (get-patient-info (patient-id principal))
  (map-get? patients { patient-id: patient-id })
)

(define-read-only (get-provider-info (provider-id principal))
  (map-get? healthcare-providers { provider-id: provider-id })
)

(define-read-only (get-health-record (record-id uint))
  (map-get? health-records { record-id: record-id })
)

(define-read-only (get-access-permission (patient-id principal) (provider-id principal))
  (map-get? access-permissions { patient-id: patient-id, provider-id: provider-id })
)

(define-read-only (check-access-validity (patient-id principal) (provider-id principal))
  (let
    (
      (current-block (var-get block-counter))
      (access-info (map-get? access-permissions { patient-id: patient-id, provider-id: provider-id }))
    )
    (match access-info
      permission
      (and
        (get is-active permission)
        (< current-block (get expires-at permission))
      )
      false
    )
  )
)

(define-read-only (get-emergency-access-info (patient-id principal))
  (map-get? emergency-access { patient-id: patient-id })
)

(define-read-only (get-access-log (log-id uint))
  (map-get? access-logs { log-id: log-id })
)

(define-read-only (get-contract-stats)
  {
    total-patients: (var-get total-patients),
    total-providers: (var-get total-providers),
    total-records: (var-get total-records),
    current-block: (var-get block-counter)
  }
)

(define-read-only (get-record-version (record-id uint) (version uint))
  (map-get? record-versions { record-id: record-id, version: version })
)

(define-read-only (get-record-version-count (record-id uint))
  (map-get? record-version-count { record-id: record-id })
)

(define-read-only (get-current-record-version (record-id uint))
  (let
    (
      (version-info (map-get? record-version-count { record-id: record-id }))
    )
    (match version-info
      info
      (map-get? record-versions { record-id: record-id, version: (get current-version info) })
      none
    )
  )
)

(define-read-only (is-version-current (record-id uint) (version uint))
  (let
    (
      (version-data (map-get? record-versions { record-id: record-id, version: version }))
    )
    (match version-data
      data
      (get is-current data)
      false
    )
  )
)

(define-private (log-access (patient-id principal) (provider-id principal) (record-id uint) (action (string-ascii 20)))
  (let
    (
      (log-id (var-get next-log-id))
      (current-block (var-get block-counter))
    )
    (map-set access-logs
      { log-id: log-id }
      {
        patient-id: patient-id,
        provider-id: provider-id,
        record-id: record-id,
        action: action,
        timestamp: current-block
      }
    )
    (var-set next-log-id (+ log-id u1))
    log-id
  )
)

(define-public (batch-grant-access (providers (list 10 principal)) (expires-in-blocks uint) (access-level (string-ascii 20)) (permissions (list 10 (string-ascii 30))))
  (let
    (
      (patient-id tx-sender)
    )
    (asserts! (is-some (map-get? patients { patient-id: patient-id })) err-unauthorized)
    (ok (map process-grant-access providers))
  )
)

(define-private (process-grant-access (provider-id principal))
  (let
    (
      (patient-id tx-sender)
      (current-block (var-get block-counter))
    )
    (map-set access-permissions
      { patient-id: patient-id, provider-id: provider-id }
      {
        granted-at: current-block,
        expires-at: (+ current-block u1000),
        access-level: "read",
        is-active: true,
        permissions: (list "view-basic" "view-history")
      }
    )
    (log-access patient-id provider-id u0 "BATCH_GRANT")
  )
)

(define-public (transfer-record-ownership (record-id uint) (new-owner principal))
  (let
    (
      (current-owner tx-sender)
      (record (unwrap! (map-get? health-records { record-id: record-id }) err-not-found))
    )
    (asserts! (is-eq (get patient-id record) current-owner) err-unauthorized)
    (asserts! (is-some (map-get? patients { patient-id: new-owner })) err-not-found)
    (map-set health-records
      { record-id: record-id }
      (merge record { patient-id: new-owner, last-updated: (var-get block-counter) })
    )
    (log-access current-owner new-owner record-id "TRANSFER_RECORD")
    (ok true)
  )
)

(define-public (bulk-revoke-access (providers (list 10 principal)))
  (let
    (
      (patient-id tx-sender)
    )
    (asserts! (is-some (map-get? patients { patient-id: patient-id })) err-unauthorized)
    (ok (map process-revoke-access providers))
  )
)

(define-private (process-revoke-access (provider-id principal))
  (let
    (
      (patient-id tx-sender)
      (current-access (map-get? access-permissions { patient-id: patient-id, provider-id: provider-id }))
    )
    (match current-access
      permission
      (begin
        (map-set access-permissions
          { patient-id: patient-id, provider-id: provider-id }
          (merge permission { is-active: false })
        )
        (log-access patient-id provider-id u0 "BULK_REVOKE")
        true
      )
      false
    )
  )
)

(define-read-only (get-provider-access-count (provider-id principal))
  (len (filter check-provider-access (get-all-patients)))
)

(define-read-only (get-all-patients)
  (list tx-sender)
)

(define-private (check-provider-access (patient-id principal))
  (is-some (map-get? access-permissions { patient-id: patient-id, provider-id: tx-sender }))
)

;; ------------------------------
;; Health Metrics Tracking Feature
;; Independent feature: allows patients to log time-stamped health metrics
;; No cross-contract calls or traits; Clarity v3 compliant
;; ------------------------------

(define-constant err-empty-metric (err u200))
(define-constant err-empty-unit (err u201))

(define-data-var next-metric-id uint u1)

(define-map health-metrics
  { metric-id: uint }
  {
    patient-id: principal,
    metric-type: (string-ascii 32),
    value: uint,
    unit: (string-ascii 10),
    timestamp: uint
  }
)

(define-map patient-metric-count
  { patient-id: principal }
  { count: uint }
)

(define-map patient-metric-index
  { patient-id: principal, index: uint }
  { metric-id: uint }
)

(define-public (log-health-metric (metric-type (string-ascii 32)) (value uint) (unit (string-ascii 10)))
  (let
    (
      (patient-id tx-sender)
      (metric-id (var-get next-metric-id))
      (current-block (var-get block-counter))
      (count-entry (map-get? patient-metric-count { patient-id: patient-id }))
    )
    (asserts! (is-some (map-get? patients { patient-id: patient-id })) err-unauthorized)
    (asserts! (> (len metric-type) u0) err-empty-metric)
    (asserts! (> (len unit) u0) err-empty-unit)

    (map-set health-metrics
      { metric-id: metric-id }
      {
        patient-id: patient-id,
        metric-type: metric-type,
        value: value,
        unit: unit,
        timestamp: current-block
      }
    )

    (match count-entry
      existing
      (let ((next-index (+ (get count existing) u1)))
        (map-set patient-metric-index { patient-id: patient-id, index: next-index } { metric-id: metric-id })
        (map-set patient-metric-count { patient-id: patient-id } { count: next-index })
        next-index
      )
      (begin
        (map-set patient-metric-index { patient-id: patient-id, index: u1 } { metric-id: metric-id })
        (map-set patient-metric-count { patient-id: patient-id } { count: u1 })
        u1
      )
    )

    (var-set next-metric-id (+ metric-id u1))
    (var-set block-counter (+ (var-get block-counter) u1))
    (ok metric-id)
  )
)

(define-read-only (get-health-metric (metric-id uint))
  (map-get? health-metrics { metric-id: metric-id })
)

(define-read-only (get-patient-metrics-count (patient-id principal))
  (let ((entry (map-get? patient-metric-count { patient-id: patient-id })))
    (match entry e (get count e) u0)
  )
)

(define-read-only (get-patient-metric-id-at (patient-id principal) (index uint))
  (map-get? patient-metric-index { patient-id: patient-id, index: index })
)
