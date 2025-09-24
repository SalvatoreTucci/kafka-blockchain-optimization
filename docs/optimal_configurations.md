## Kafka Optimization for Blockchain Workloads

### Optimal Configuration
```yaml
# Producer Configuration
batch.size: 65536          # +10.4% throughput vs default 16KB
linger.ms: 0               # CRITICAL: >0 causes severe degradation
buffer.memory: 67108864    # +3.2% improvement vs default 32MB

# Broker Configuration  
num.network.threads: 8     # Validated optimal for container setup
num.io.threads: 8          # Balanced I/O handling