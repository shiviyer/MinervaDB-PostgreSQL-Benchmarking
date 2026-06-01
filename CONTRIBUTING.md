# Contributing to MinervaDB PostgreSQL Benchmarking Toolkit

Thank you for your interest in contributing! This toolkit aims to be the most comprehensive, enterprise-grade PostgreSQL benchmarking resource available. Contributions from DBAs, architects, and performance engineers are greatly appreciated.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Types of Contributions](#types-of-contributions)
- [Contribution Standards](#contribution-standards)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Script Standards](#script-standards)
- [Documentation Standards](#documentation-standards)
- [Testing Requirements](#testing-requirements)

---

## Code of Conduct

This project follows a professional code of conduct. Be respectful, constructive, and focused on improving the toolkit for the PostgreSQL community.

---

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/MinervaDB-PostgreSQL-Benchmarking.git
   cd MinervaDB-PostgreSQL-Benchmarking
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-benchmark-scenario
   ```
4. **Install dependencies**:
   ```bash
   sudo bash 00-prerequisites/install-dependencies.sh
   ```
5. **Test your changes** against PostgreSQL 15+ before submitting

---

## Types of Contributions

### High Priority (most welcome)

- **New benchmark scripts** for specific workload patterns (SaaS, fintech, healthcare, IoT)
- **PostgreSQL version-specific** configurations and tuning notes for PG 17/18
- **Cloud provider benchmarks** (AWS RDS, Aurora, GCP AlloyDB, Azure Flexible)
- **Capacity planning formulas** validated against production deployments
- **Runbook improvements** with real-world experience and edge cases
- **Result visualization** improvements to the Python analysis tools

### Also Welcome

- Bug fixes in existing scripts
- Documentation improvements and corrections
- Additional how-to guides
- Example workloads for new application types
- Translations of documentation

---

## Contribution Standards

### Shell Scripts

All shell scripts must follow these standards:

```bash
#!/usr/bin/env bash
# =============================================================================
# MinervaDB PostgreSQL Benchmarking Toolkit
# script-name.sh - Brief description
# =============================================================================
# Author:     Your Name / GitHub: @yourusername
# Version:    1.0.0
# Compatible: Ubuntu 20.04+, RHEL 8+, macOS 12+
# PostgreSQL: 15, 16, 17, 18
# =============================================================================

set -euo pipefail  # Required: strict mode

# Variables must be UPPERCASE for globals, lowercase for locals
GLOBAL_VAR="value"
local_var="value"

# All scripts must have:
# 1. A usage() function with --help support
# 2. Argument parsing via while/case
# 3. Pre-flight validation
# 4. Structured output with colors
# 5. Results written to --output directory
```

### Python Scripts

```python
#!/usr/bin/env python3
"""
MinervaDB PostgreSQL Benchmarking Toolkit
module-name.py - Brief description

Compatible with Python 3.8+
Dependencies: Listed in requirements.txt
"""

# Standard library imports first
import os
import sys

# Third-party imports next
import psycopg2

# Type hints are required for public functions
def analyze_results(input_dir: str, output_format: str = 'table') -> dict:
    """
    Analyze benchmark results from directory.
    
    Args:
        input_dir: Path to directory containing benchmark result files
        output_format: Output format ('table', 'json', 'csv')
    
    Returns:
        Dictionary with analysis results
    """
    pass
```

### Configuration Files

Configuration files (`.conf`) must include:
- Section headers with category names
- Comments explaining each parameter
- Rule-of-thumb guidance for sizing
- Version compatibility notes

---

## Submitting Pull Requests

### PR Requirements

- [ ] Branch name: `feature/description` or `fix/description`
- [ ] Title: Clear, concise description of the change
- [ ] Description: What, why, and how
- [ ] Tests: Verified against PostgreSQL 15 or 16 minimum
- [ ] Documentation: Updated relevant README/howto files
- [ ] No hardcoded credentials or server-specific values

### PR Template

```markdown
## Summary
Brief description of the change.

## Type of Change
- [ ] New benchmark script/scenario
- [ ] Bug fix
- [ ] Documentation update
- [ ] Performance improvement
- [ ] New how-to guide

## PostgreSQL Versions Tested
- [ ] PG 15
- [ ] PG 16
- [ ] PG 17
- [ ] PG 18

## OS Tested
- [ ] Ubuntu 22.04
- [ ] RHEL/AlmaLinux 9
- [ ] macOS

## Checklist
- [ ] Script has usage() and --help
- [ ] set -euo pipefail is present
- [ ] No hardcoded passwords
- [ ] Results are written to configurable output directory
- [ ] Documentation updated
```

---

## Testing Requirements

Before submitting, run:

```bash
# Validate your script runs without errors
bash your-script.sh --help

# Run environment validation
bash 00-prerequisites/environment-validation.sh

# Test against a real PostgreSQL instance
bash your-script.sh --host localhost --duration 60
```

---

## Questions?

Open a GitHub Issue or reach out via:
- **GitHub Issues**: https://github.com/shiviyer/MinervaDB-PostgreSQL-Benchmarking/issues
- **MinervaDB**: https://minervadb.com

---

*Thank you for helping make this the best PostgreSQL benchmarking toolkit available!*
