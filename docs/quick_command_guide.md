# Blockchain Benchmark - Quick Command Reference

> **Guida rapida per eseguire benchmark completi su configurazioni Kafka ottimizzate per blockchain**

---

## 📋 Table of Contents

- [Setup Iniziale](#setup-iniziale)
- [Esecuzione Benchmark](#esecuzione-benchmark)
- [Analisi Risultati](#analisi-risultati)
- [Stress Test (Opzionale)](#stress-test-opzionale)
- [Visualizzazione Output](#visualizzazione-output)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)

---

## Setup Iniziale

> **Nota:** Eseguire questi comandi una sola volta prima di iniziare i test.

### Step 1: Deploy Environment

```bash
./scripts/deploy/deploy-baseline.sh
```

Inizializza l'infrastruttura Docker (Kafka, Zookeeper, test-runner).

### Step 2: Verify Setup

```bash
./scripts/test/quick-test.sh
```

Verifica che tutti i servizi siano operativi.

### Step 3: Test Blockchain Simulator

```bash
docker-compose exec test-runner python3 ./scripts/blockchain/blockchain_simulator.py
```

Testa il simulatore blockchain standalone.

### Step 4: Smoke Test

```bash
docker-compose exec test-runner python3 ./scripts/blockchain/run-blockchain-benchmark.py \
  --config test \
  --batch-size 16384 \
  --linger-ms 0 \
  --transactions 1000
```

Test rapido con 1000 transazioni per validare la configurazione.

---

## Esecuzione Benchmark

### Step 5: Create Stress Test Topic (Opzionale)

```bash
docker-compose exec kafka kafka-topics \
  --create --topic blockchain-stress \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists
```

Necessario solo se si vuole eseguire lo stress test (Step 10).

### Step 6: Run Complete Benchmark Suite

```bash
./run-blockchain-benchmarks.sh 5000
```

Esegue tutti i benchmark con 5000 transazioni per configurazione:
- **baseline**: Configurazione Kafka default
- **batch-optimized**: Batch size ottimizzato
- **high-throughput**: Massima velocità
- **low-latency**: Minima latenza

### Step 7: Copy Results from Container

```bash
cd blockchain_benchmark_results_YYYYMMDD_HHMMSS/

docker cp test-runner:/results/blockchain_baseline_TIMESTAMP.json \
  ./baseline_result.json

docker cp test-runner:/results/blockchain_batch-optimized_TIMESTAMP.json \
  ./batch-optimized_result.json

docker cp test-runner:/results/blockchain_high-throughput_TIMESTAMP.json \
  ./high-throughput_result.json

docker cp test-runner:/results/blockchain_low-latency_TIMESTAMP.json \
  ./low-latency_result.json

cd ..
```

> **Importante:** Sostituire `YYYYMMDD_HHMMSS` e `TIMESTAMP` con i valori effettivi. Vedere [Troubleshooting](#troubleshooting) per trovare i timestamp corretti.

---

## Analisi Risultati

### Step 8: Analyze Blockchain Results

```bash
python3 analyze_blockchain_results.py blockchain_benchmark_results_YYYYMMDD_HHMMSS
```

Genera analisi comparative delle configurazioni testate.

**Output atteso:**
```
Highest Throughput: high-throughput (9828 TPS)
```

### Step 9: Generate Pareto Frontier Charts

```bash
python3 ./scripts/analysis/pareto-analysis.py
```

Crea grafici di ottimalità Pareto per visualizzare trade-off throughput/latency.

**Output atteso:**
```
✓ Complete Pareto analysis saved: results/pareto_analysis/pareto_frontier_complete.png
Most Efficient: High-Throughput (3723 TPS/CPU%)
```

---

## Stress Test (Opzionale)

### Step 10: Run Multi-Producer Stress Test

```bash
docker-compose exec test-runner python3 ./scripts/test/stress-test-benchmark.py
```

Testa robustezza del sistema con produttori multipli simultanei.

> **Prerequisito:** Aver eseguito Step 5 per creare il topic `blockchain-stress`.

---

## Visualizzazione Output

### Elencare File Generati

```bash
# Risultati benchmark
ls -la blockchain_benchmark_results_YYYYMMDD_HHMMSS/

# Grafici Pareto
ls -la results/pareto_analysis/
```

### Visualizzare Report Analisi

```bash
cat blockchain_benchmark_results_YYYYMMDD_HHMMSS/BLOCKCHAIN_ANALYSIS_REPORT.md
```

---

## Cleanup

### Stop Containers

```bash
docker-compose down
```

Ferma tutti i container mantenendo volumi e dati.

### Complete Cleanup (Fresh Start)

```bash
docker-compose down -v
```

Rimuove container, network e volumi per un ambiente pulito.

---

## Troubleshooting

### Trovare Timestamp Corretti

#### Metodo 1: List Files in Container

```bash
docker-compose exec test-runner ls -la /results/ | grep blockchain_
```

#### Metodo 2: Find Command

```bash
docker-compose exec test-runner find /results -name "blockchain_*.json"
```

### Se Step 7 Fallisce (Timestamp Errato)

```bash
# Copia tutti i risultati in directory temporanea
docker cp test-runner:/results/ ./temp_results/

# Rinomina manualmente i file
mv ./temp_results/blockchain_baseline_*.json ./baseline_result.json
mv ./temp_results/blockchain_batch-optimized_*.json ./batch-optimized_result.json
mv ./temp_results/blockchain_high-throughput_*.json ./high-throughput_result.json
mv ./temp_results/blockchain_low-latency_*.json ./low-latency_result.json

# Pulisci directory temporanea
rm -rf ./temp_results/
```

### Verificare Integrità Risultati

#### Check File Size

```bash
ls -lh blockchain_benchmark_results_*/baseline_result.json
```

**Output atteso:** ~10KB per file

#### Inspect JSON Content

```bash
head -20 blockchain_benchmark_results_*/baseline_result.json
```

Verifica che il file JSON sia ben formato e contenga dati validi.

---

## Output Attesi per Validazione

| Step | Comando | Output Chiave |
|------|---------|---------------|
| **Step 2** | `quick-test.sh` | `✓ All services healthy` |
| **Step 4** | Smoke test | `Results saved: /results/blockchain_test_*.json` |
| **Step 6** | Benchmark suite | 4 file JSON creati in `/results/` |
| **Step 8** | Analysis | `Highest Throughput: high-throughput (9828 TPS)` |
| **Step 9** | Pareto analysis | `Most Efficient: High-Throughput (3723 TPS/CPU%)` |

---

## Lista comandi in sequenza

# Setup
./scripts/deploy/deploy-baseline.sh
./scripts/test/quick-test.sh
docker-compose exec test-runner python3 ./scripts/blockchain/blockchain_simulator.py
docker-compose exec test-runner python3 ./scripts/blockchain/run-blockchain-benchmark.py --config test --batch-size 16384 --linger-ms 0 --transactions 1000
# Benchmark
docker-compose exec kafka kafka-topics --create --topic blockchain-stress --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists
./run-blockchain-benchmarks.sh 5000
# Copy Results
cd blockchain_benchmark_results_YYYYMMDD_HHMMSS/
docker cp test-runner:/results/blockchain_baseline_TIMESTAMP.json ./baseline_result.json
docker cp test-runner:/results/blockchain_batch-optimized_TIMESTAMP.json ./batch-optimized_result.json
docker cp test-runner:/results/blockchain_high-throughput_TIMESTAMP.json ./high-throughput_result.json
docker cp test-runner:/results/blockchain_low-latency_TIMESTAMP.json ./low-latency_result.json
cd ..
# Analysis
python3 analyze_blockchain_results.py blockchain_benchmark_results_YYYYMMDD_HHMMSS
python3 ./scripts/analysis/pareto-analysis.py
# Stress Test (Optional)
docker-compose exec test-runner python3 ./scripts/test/stress-test-benchmark.py
# View Results
ls -la blockchain_benchmark_results_YYYYMMDD_HHMMSS/
ls -la results/pareto_analysis/
cat blockchain_benchmark_results_YYYYMMDD_HHMMSS/BLOCKCHAIN_ANALYSIS_REPORT.md
# Cleanup
docker-compose down
docker-compose down -v
# Troubleshooting
docker-compose exec test-runner ls -la /results/ | grep blockchain_
docker-compose exec test-runner find /results -name "blockchain_*.json"
docker cp test-runner:/results/ ./temp_results/
ls -lh blockchain_benchmark_results_*/baseline_result.json
head -20 blockchain_benchmark_results_*/baseline_result.json

---

## Note Finali

- **Durata totale:** ~15-20 minuti per benchmark completo (Step 6-9)
- **Spazio disco:** ~50MB per set completo di risultati
- **Riproducibilità:** Tutti i comandi sono idempotenti e possono essere rieseguiti

> Per domande o problemi, consultare la documentazione completa in `/docs/` o verificare i log dei container con `docker-compose logs -f`

--