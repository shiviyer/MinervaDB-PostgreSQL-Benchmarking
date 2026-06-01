#!/usr/bin/env python3
"""
MinervaDB PostgreSQL Benchmarking Toolkit
result-analyzer.py - Benchmark Results Analysis & Visualization

Parses pgbench, sysbench, and HammerDB output files and produces:
- Summary statistics table
- TPS vs. client count curves
- Latency percentile distribution
- Cache hit ratio analysis
- Exportable CSV/JSON data

USAGE:
    python3 tools/result-analyzer.py --input results/ [OPTIONS]

EXAMPLES:
    # Analyze all results in a directory
    python3 tools/result-analyzer.py --input results/oltp-20260601/

    # Generate TPS curve chart
    python3 tools/result-analyzer.py --input results/ --chart tps-curve

    # Export to CSV
    python3 tools/result-analyzer.py --input results/ --format csv --output data.csv
"""

import os
import re
import sys
import json
import csv
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict


# =============================================================================
# Data Models
# =============================================================================

@dataclass
class BenchmarkResult:
    """Represents a single benchmark run result"""
    run_id: str
    tool: str                      # pgbench, sysbench, hammerdb
    timestamp: str
    host: str
    scale_factor: int
    clients: int
    threads: int
    duration: int
    tps: float                     # Transactions per second
    tps_including_connections: float
    latency_avg_ms: float
    latency_stddev_ms: float
    latency_p50_ms: Optional[float] = None
    latency_p95_ms: Optional[float] = None
    latency_p99_ms: Optional[float] = None
    latency_p999_ms: Optional[float] = None
    initial_connect_ms: Optional[float] = None
    transactions_processed: Optional[int] = None
    errors: Optional[int] = None
    cache_hit_pct: Optional[float] = None
    source_file: str = ""


# =============================================================================
# Parsers
# =============================================================================

class PgbenchParser:
    """Parse pgbench output files"""
    
    @staticmethod
    def parse(filepath: str) -> Optional[BenchmarkResult]:
        try:
            with open(filepath, 'r') as f:
                content = f.read()
        except Exception as e:
            print(f"  Warning: Cannot read {filepath}: {e}")
            return None
        
        # Extract TPS (excluding connection establishment)
        tps_match = re.search(r'tps = ([\.\d]+) \(without initial connection time\)', content)
        tps_conn_match = re.search(r'tps = ([\.\d]+) \(including connections\)', content)
        
        if not tps_match:
            # Try alternative format
            tps_match = re.search(r'tps = ([\.\d]+) \(excluding connections', content)
        
        if not tps_match:
            return None
        
        tps = float(tps_match.group(1))
        tps_conn = float(tps_conn_match.group(1)) if tps_conn_match else tps
        
        # Extract latency
        lat_avg = re.search(r'latency average = ([\.\d]+) ms', content)
        lat_std = re.search(r'latency stddev = ([\.\d]+) ms', content)
        
        # Extract percentiles (pgbench --report-latencies)
        lat_p50 = re.search(r'50th percentile.*?: ([\.\d]+)', content)
        lat_p95 = re.search(r'95th percentile.*?: ([\.\d]+)', content)
        lat_p99 = re.search(r'99th percentile.*?: ([\.\d]+)', content)
        
        # Extract config
        clients_match = re.search(r'number of clients: (\d+)', content)
        threads_match = re.search(r'number of threads: (\d+)', content)
        duration_match = re.search(r'duration: (\d+) s', content)
        transactions_match = re.search(r'number of transactions actually processed: (\d+)', content)
        
        # Extract scale factor from init log or filename
        scale_match = re.search(r'scaling factor: (\d+)', content)
        scale = int(scale_match.group(1)) if scale_match else 0
        
        filename = Path(filepath).stem
        timestamp = datetime.now().isoformat()
        
        return BenchmarkResult(
            run_id=filename,
            tool="pgbench",
            timestamp=timestamp,
            host="localhost",
            scale_factor=scale,
            clients=int(clients_match.group(1)) if clients_match else 0,
            threads=int(threads_match.group(1)) if threads_match else 0,
            duration=int(duration_match.group(1)) if duration_match else 0,
            tps=tps,
            tps_including_connections=tps_conn,
            latency_avg_ms=float(lat_avg.group(1)) if lat_avg else 0,
            latency_stddev_ms=float(lat_std.group(1)) if lat_std else 0,
            latency_p50_ms=float(lat_p50.group(1)) if lat_p50 else None,
            latency_p95_ms=float(lat_p95.group(1)) if lat_p95 else None,
            latency_p99_ms=float(lat_p99.group(1)) if lat_p99 else None,
            transactions_processed=int(transactions_match.group(1)) if transactions_match else None,
            source_file=filepath
        )


class SysbenchParser:
    """Parse sysbench output files"""
    
    @staticmethod
    def parse(filepath: str) -> Optional[BenchmarkResult]:
        try:
            with open(filepath, 'r') as f:
                content = f.read()
        except Exception as e:
            print(f"  Warning: Cannot read {filepath}: {e}")
            return None
        
        # TPS
        tps_match = re.search(r'transactions:\s+\d+ \(([\.\d]+) per sec\.\)', content)
        qps_match = re.search(r'queries:\s+\d+ \(([\.\d]+) per sec\.\)', content)
        
        if not tps_match:
            return None
        
        # Latency percentiles
        lat_min = re.search(r'min:\s+([\.\d]+)', content)
        lat_avg = re.search(r'avg:\s+([\.\d]+)', content)
        lat_max = re.search(r'max:\s+([\.\d]+)', content)
        lat_p95 = re.search(r'95th percentile:\s+([\.\d]+)', content)
        lat_p99 = re.search(r'99th percentile:\s+([\.\d]+)', content)
        
        threads_match = re.search(r'Number of threads: (\d+)', content)
        
        filename = Path(filepath).stem
        
        return BenchmarkResult(
            run_id=filename,
            tool="sysbench",
            timestamp=datetime.now().isoformat(),
            host="localhost",
            scale_factor=0,
            clients=int(threads_match.group(1)) if threads_match else 0,
            threads=int(threads_match.group(1)) if threads_match else 0,
            duration=0,
            tps=float(tps_match.group(1)),
            tps_including_connections=float(tps_match.group(1)),
            latency_avg_ms=float(lat_avg.group(1)) if lat_avg else 0,
            latency_stddev_ms=0,
            latency_p95_ms=float(lat_p95.group(1)) if lat_p95 else None,
            latency_p99_ms=float(lat_p99.group(1)) if lat_p99 else None,
            source_file=filepath
        )


# =============================================================================
# Analysis Functions
# =============================================================================

class ResultAnalyzer:
    """Analyze and report on benchmark results"""
    
    def __init__(self, results: List[BenchmarkResult]):
        self.results = results
    
    def summary_table(self) -> str:
        """Generate ASCII summary table"""
        if not self.results:
            return "No results to display"
        
        header = (
            f"{'Run ID':<35} {'Tool':<10} {'Clients':<8} "
            f"{'TPS':<12} {'Avg Lat(ms)':<13} {'P99 Lat(ms)':<12} "
            f"{'Duration':<10}"
        )
        separator = "-" * len(header)
        
        rows = [header, separator]
        for r in sorted(self.results, key=lambda x: x.tps, reverse=True):
            p99 = f"{r.latency_p99_ms:.1f}" if r.latency_p99_ms else "N/A"
            row = (
                f"{r.run_id[:35]:<35} {r.tool:<10} {r.clients:<8} "
                f"{r.tps:<12.1f} {r.latency_avg_ms:<13.2f} {p99:<12} "
                f"{r.duration}s"
            )
            rows.append(row)
        
        return "\n".join(rows)
    
    def best_result(self) -> Optional[BenchmarkResult]:
        """Return result with highest TPS"""
        if not self.results:
            return None
        return max(self.results, key=lambda r: r.tps)
    
    def tps_by_clients(self) -> Dict[int, float]:
        """Group TPS by client count for curve analysis"""
        result = {}
        for r in self.results:
            if r.clients > 0:
                if r.clients not in result or r.tps > result[r.clients]:
                    result[r.clients] = r.tps
        return dict(sorted(result.items()))
    
    def find_saturation_point(self) -> Tuple[int, float]:
        """Find client count where TPS stops increasing (saturation)"""
        tps_by_clients = self.tps_by_clients()
        if len(tps_by_clients) < 2:
            return (0, 0)
        
        items = list(tps_by_clients.items())
        max_tps = max(v for _, v in items)
        
        for i, (clients, tps) in enumerate(items):
            # Saturation = TPS within 5% of max and subsequent points don't improve
            if tps >= max_tps * 0.95:
                return (clients, tps)
        
        return items[-1]
    
    def recommendations(self) -> List[str]:
        """Generate performance recommendations based on results"""
        recs = []
        best = self.best_result()
        
        if not best:
            return ["No benchmark data available for analysis"]
        
        if best.tps < 1000:
            recs.append("Low TPS detected. Investigate: shared_buffers size, "
                       "index coverage, synchronous_commit setting")
        
        if best.latency_avg_ms > 50:
            recs.append("High average latency. Check: lock contention, "
                       "checkpoint frequency, storage I/O performance")
        
        if best.latency_stddev_ms > best.latency_avg_ms * 2:
            recs.append("High latency variance (stddev). Investigate: "
                       "autovacuum interference, checkpoint spikes, THP")
        
        if best.cache_hit_pct and best.cache_hit_pct < 99:
            recs.append(f"Cache hit ratio {best.cache_hit_pct:.1f}% is below 99%. "
                       "Increase shared_buffers or add more RAM")
        
        # TPS curve analysis
        sat_clients, sat_tps = self.find_saturation_point()
        if sat_clients > 0:
            recs.append(f"TPS saturation occurs at approximately {sat_clients} clients "
                       f"({sat_tps:.0f} TPS peak). Consider this as your effective "
                       f"max_connections target for PgBouncer configuration")
        
        if not recs:
            recs.append("Results look healthy! No critical issues detected.")
        
        return recs
    
    def export_json(self, output_path: str):
        """Export results to JSON"""
        data = {
            "generated_at": datetime.now().isoformat(),
            "toolkit": "MinervaDB PostgreSQL Benchmarking Toolkit",
            "total_runs": len(self.results),
            "best_tps": self.best_result().tps if self.best_result() else 0,
            "results": [asdict(r) for r in self.results]
        }
        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"Results exported to JSON: {output_path}")
    
    def export_csv(self, output_path: str):
        """Export results to CSV"""
        if not self.results:
            print("No results to export")
            return
        
        fieldnames = list(asdict(self.results[0]).keys())
        with open(output_path, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for r in self.results:
                writer.writerow(asdict(r))
        print(f"Results exported to CSV: {output_path}")


# =============================================================================
# File Discovery
# =============================================================================

def discover_result_files(input_dir: str) -> List[str]:
    """Find all benchmark result files in directory"""
    result_files = []
    patterns = ['*results*.txt', '*pgbench*.txt', '*sysbench*.txt', 
                '*hammerdb*.txt', '*benchmark*.log']
    
    for pattern in patterns:
        result_files.extend(Path(input_dir).glob(f"**/{pattern}"))
    
    return [str(f) for f in set(result_files)]


def load_results(input_dir: str) -> List[BenchmarkResult]:
    """Load and parse all results from directory"""
    results = []
    files = discover_result_files(input_dir)
    
    print(f"Found {len(files)} result files in {input_dir}")
    
    for filepath in files:
        print(f"  Parsing: {Path(filepath).name}")
        
        # Try pgbench parser
        result = PgbenchParser.parse(filepath)
        if result:
            results.append(result)
            continue
        
        # Try sysbench parser
        result = SysbenchParser.parse(filepath)
        if result:
            results.append(result)
    
    print(f"Successfully parsed {len(results)} benchmark results")
    return results


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='MinervaDB PostgreSQL Benchmarking - Result Analyzer',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument('--input', '-i', required=True, 
                       help='Input directory containing benchmark results')
    parser.add_argument('--output', '-o', 
                       help='Output file path (for CSV/JSON export)')
    parser.add_argument('--format', choices=['table', 'json', 'csv'], 
                       default='table', help='Output format')
    parser.add_argument('--mode', choices=['summary', 'tps-curve', 'recommendations'],
                       default='summary', help='Analysis mode')
    parser.add_argument('--chart', action='store_true',
                       help='Generate charts (requires matplotlib)')
    
    args = parser.parse_args()
    
    print("=" * 70)
    print("  MinervaDB PostgreSQL Benchmarking Toolkit - Result Analyzer")
    print("=" * 70)
    print()
    
    # Load results
    results = load_results(args.input)
    
    if not results:
        print("No benchmark results found. Ensure result files are in the input directory.")
        sys.exit(1)
    
    analyzer = ResultAnalyzer(results)
    
    # Output based on format
    if args.format == 'json':
        output = args.output or f"benchmark-results-{datetime.now().strftime('%Y%m%d')}.json"
        analyzer.export_json(output)
    elif args.format == 'csv':
        output = args.output or f"benchmark-results-{datetime.now().strftime('%Y%m%d')}.csv"
        analyzer.export_csv(output)
    else:
        # Table mode - display summary
        print("\nRESULTS SUMMARY")
        print("=" * 70)
        print(analyzer.summary_table())
        
        # Best result
        best = analyzer.best_result()
        if best:
            print(f"\nPEAK PERFORMANCE")
            print(f"  Tool:           {best.tool}")
            print(f"  TPS:            {best.tps:.1f}")
            print(f"  Clients:        {best.clients}")
            print(f"  Avg Latency:    {best.latency_avg_ms:.2f} ms")
            if best.latency_p99_ms:
                print(f"  P99 Latency:    {best.latency_p99_ms:.2f} ms")
        
        # TPS curve
        if args.mode == 'tps-curve':
            print(f"\nTPS vs. CLIENTS CURVE")
            curve = analyzer.tps_by_clients()
            for clients, tps in curve.items():
                bar_len = int(tps / max(curve.values()) * 40)
                bar = "█" * bar_len
                print(f"  {clients:4d} clients: {bar:<40} {tps:.0f} TPS")
        
        # Recommendations
        print(f"\nRECOMMENDATIONS")
        for i, rec in enumerate(analyzer.recommendations(), 1):
            print(f"  {i}. {rec}")
    
    print("\n" + "=" * 70)
    print("  Analysis complete | MinervaDB PostgreSQL Benchmarking Toolkit")
    print("  https://github.com/shiviyer/MinervaDB-PostgreSQL-Benchmarking")
    print("=" * 70)


if __name__ == "__main__":
    main()
