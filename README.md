# Patient-Owned Health Records (POHR)

A decentralized healthcare data management platform built on Stacks blockchain, giving patients complete ownership and control over their medical records.

## Overview

POHR enables patients to:
- Own and control their medical data
- Grant temporary, revocable access to healthcare providers
- Maintain a unified, secure health record across all providers
- Set emergency access protocols
- Track all data access through immutable logs

## Smart Contract Features

### Core Functionality
- **Patient Registration**: Register as a patient with basic information
- **Provider Registration**: Healthcare providers can register and get verified
- **Health Records Management**: Add, update, and transfer health records
- **Access Control**: Grant/revoke provider access with customizable permissions
- **Emergency Access**: Configure emergency access for critical situations
- **Audit Logging**: Complete access history tracking

### Key Functions

#### Patient Functions
```clarity
(register-patient "John Doe" u19850315 "emergency@contact.com")
(add-health-record "blood-test" 0x1234... true)
(grant-access 'SP2PROVIDER... u1000 "read" (list "view-basic" "view-history"))
(revoke-access 'SP2PROVIDER...)
(set-emergency-access true (list 'SP2EMERGENCY...) "diabetes-insulin")
```

#### Provider Functions
```clarity
(register-provider "City Hospital" "LIC123456" "cardiology")
(access-health-record 'SP2PATIENT... u1)
(emergency-access-record 'SP2PATIENT... u1)
```

#### Administrative Functions
```clarity
(verify-provider 'SP2PROVIDER...)
```

## Usage Instructions

### 1. Patient Onboarding
1. Call `register-patient` with your name, date of birth, and emergency contact
2. Add health records using `add-health-record` with encrypted data hashes
3. Configure emergency access with `set-emergency-access`

### 2. Healthcare Provider Setup
1. Register using `register-provider` with credentials
2. Wait for admin verification via `verify-provider`
3. Request patient access through off-chain communication

### 3. Data Access Management
1. Patients grant access using `grant-access` with specific time limits and permissions
2. Providers access records using `access-health-record`
3. Patients can revoke access anytime with `revoke-access`

### 4. Emergency Protocols
- Configure emergency access settings
- Designated emergency contacts can access critical records
- Emergency access bypasses normal permission checks

## Data Model

### Patient Record
- Name, date of birth, emergency contact
- Account status and creation timestamp

### Health Record
- Patient ownership, record type, encrypted data hash
- Creation and update timestamps
- Encryption status

### Access Permissions
- Time-bound access with specific permissions
- Customizable access levels (read, write, emergency)
- Revocation capabilities

### Audit Logs
- Complete access history
- Action tracking (grant, revoke, access, emergency)
- Immutable audit trail

## Security Features

- **Patient-Owned**: Only patients control their data
- **Time-Limited Access**: All permissions have expiration dates
- **Granular Permissions**: Specific access levels and action permissions
- **Emergency Protocols**: Secure emergency access for critical situations
- **Provider Verification**: Administrative verification required for providers
- **Audit Trail**: Complete immutable access logging
- **Encrypted Storage**: Support for encrypted health data

## Installation

1. Ensure Clarinet is installed
2. Clone the repository
3. Run `clarinet check` to verify contract syntax
4. Deploy using `clarinet deploy`

## Testing

Run the test suite:
```bash
clarinet test
```

## License

This project is licensed under the MIT License.
