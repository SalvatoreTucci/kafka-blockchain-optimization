# Paper Analysis: Kafka vs Raft in Blockchain

## Summary of Research Gap

Analysis of 3 key papers reveals a consistent pattern:
- **All studies use default Kafka configurations**
- **None optimize Kafka parameters for blockchain workloads**
- **Performance gaps may be due to misconfiguration, not architectural limitations**

---

## Paper 1: "Log Replication in Raft vs Kafka" (2020)

**Key Finding**: Conceptual comparison only - no performance testing
**Kafka Config**: Basic cluster setup, minimal configuration details
**Gap**: Purely theoretical - calls for benchmark development
**Opportunity**: This paper explicitly suggests developing performance benchmarks

---

## Paper 2: "Performance Evaluation of Ordering Services" (2021+)

**Key Finding**: 
- Raft recommended as "best choice for most organizations"
- Validation phase identified as system bottleneck
- Kafka described as "more complex with few additional benefits"

**Test Setup**:
- 32 commercial nodes cluster
- Intel Xeon E5-1603 (2.80GHz), 16GB RAM
- Smallbank benchmark
- Block size: 100 transactions, 3s timeout

**Kafka Config**: Default settings, only mentions `m` parameter (replication factor)
**Gap**: No parameter optimization attempted
**Opportunity**: Test environment well-documented - can replicate baseline

---

## Paper 3: "Resource Analysis of Blockchain Consensus Algorithms" (2022)

**Key Findings**:
- **Raft consumes 35% and 65% fewer CPU cycles than Kafka and PBFT**
- **Kafka consumes less network bandwidth than others**
- Resource consumption differs up to 7x between algorithms
- Batch size significantly impacts performance

**Test Setup**:
- 355 test cases across multiple parameters
- 7 physical servers, Intel Xeon CPU E5-2650
- Hyperledger Fabric v1.4, Caliper benchmark
- Smallbank, simple, and marbles chaincodes

**Kafka Config**: 
- 4 broker nodes, 3 Zookeeper nodes  
- Default `m=3` replication factor
- No other parameters optimized

**Critical Gap**: Despite 355 test cases, **zero Kafka parameter optimization**
**Opportunity**: Bandwidth efficiency suggests architectural advantage - optimization could unlock performance

---

## Research Opportunity Quantified

### Baseline Numbers to Beat:
- **Raft CPU advantage**: 35% less than default Kafka
- **Kafka bandwidth advantage**: Lower than Raft (specific numbers available)
- **Test scale**: Up to 32 nodes, 1000 TPS workloads
- **Hardware baseline**: Well-documented specs for replication

### Parameters Never Tested in Blockchain Context:
- batch.size (16KB default → test up to 256KB)
- linger.ms (0 default → test up to 100ms)  
- compression.type (none → snappy, lz4, gzip, zstd)
- num.network.threads (3 → up to 32)
- buffer.memory (32MB → up to 256MB)

### Success Criteria:
1. **Beat Raft baseline throughput** from Paper 2
2. **Achieve better resource efficiency** than Paper 3 default Kafka
3. **Maintain or improve latency** compared to existing results
4. **Document optimal configurations** for different workload patterns

---

## Next Steps

1. **Replicate Paper 2 baseline** (Raft vs default Kafka)
2. **Implement Paper 3 resource monitoring** (CPU, memory, network)
3. **Systematically test parameters** identified in literature
4. **Compare against published baselines** for validation

This analysis provides concrete baselines to beat and specific parameters to optimize - exactly what was missing in previous research.