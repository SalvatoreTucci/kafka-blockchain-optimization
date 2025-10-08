# MAPPA CITAZIONI - CAPITOLI 2 E 3

## [1] HARRIS C. (2021)

### Capitolo 2 - Background e Fondamenti Teorici

**2.1 Apache Kafka (introduzione):**
- "gap prestazionale rispetto ad alternative come Raft quando si utilizzano configurazioni di default"

**2.1.2 Replication, Partitioning e Fault Tolerance:**
- "Harris evidenzia che questa configurazione, pur accettando latenze leggermente superiori, è necessaria per garantire le garanzie di consistenza richieste dal consensus blockchain"

**2.3 Algoritmi di Consenso Alternativi:**
- "Gli studi evidenziano vantaggi operativi di Raft rispetto a Kafka, con performance competitive (~300 TPS) ma deployment semplificato"

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.1.1 Studi Comparativi tra Algoritmi di Consenso:**
- "Il lavoro di Harris (2021) rappresenta uno dei contributi più citati, offrendo comparazione sistematica tra Kafka, Raft e Solo utilizzando Hyperledger Caliper con il workload Smallbank"
- "I risultati evidenziano che Raft raggiunge ~300 TPS con latenze inferiori ai 5 secondi, posizionandosi come 'best choice' per la maggioranza degli scenari enterprise"
- "Kafka mostra throughput comparabili ma con overhead operativo superiore dovuto alla gestione di cluster esterni di broker e Zookeeper"
- "L'autore sottolinea come la semplicità di deployment di Raft costituisca un vantaggio concreto"

**3.3.1 Risultati Consolidati:**
- "compromesso intelligente tra performance (~300 TPS), semplicità operativa, e fault tolerance"

**3.3.2 Posizionamento della Tesi:**
- "Harris dimostra la superiorità operativa di Raft confrontandolo con Kafka-default"

---

## [2] YANG G., LEE K. et al. (2022)

### Capitolo 2 - Background e Fondamenti Teorici

**2.1.1 Architettura Producer-Broker-Consumer:**
- "Il prezzo da pagare è una latenza aggiuntiva proporzionale al tempo di attesa per riempire il batch"

**2.1.3 Parametri Critici per le Performance:**
- "La letteratura scientifica ha identificato alcuni parametri particolarmente critici"
- "Gli studi empirici dimostrano che l'incremento di batch.size può produrre guadagni significativi"
- "Questo significa che serve un flusso sostenuto di transazioni per riempire rapidamente il batch"
- "esperimenti condotti con differenti tassi di generazione transazionale rivelano..."
- "Valori superiori a 200KB cominciano a degradare le performance"
- "La letteratura documenta che incrementare linger.ms migliora il throughput al costo di maggiore latenza"
- "Yang et al. dimostrano che nei workload blockchain la compressione ha un impatto minimo o addirittura negativo"
- "Testando lz4 e snappy su transazioni Hyperledger Fabric (~1KB payload)..."
- "La spiegazione di questo risultato apparentemente controintuitivo risiede nella natura delle transazioni blockchain"
- "Il parametro num.network.threads definisce il numero di thread dedicati alla gestione delle richieste di rete: incrementarlo da 3 (default) a 6-8 in scenari ad alto traffico riduce la latenza"
- "Gli studi empirici sono chiari nel quantificare l'impatto relativo: nei workload blockchain, l'ottimizzazione broker-side ha un impatto limitato (~5%) rispetto all'ottimizzazione producer-side (~35%)"

**2.2 Blockchain Ordering Services:**
- "Le transazioni blockchain hanno dimensioni relativamente contenute, tipicamente nell'ordine di 1KB, ma arrivano in pattern bursty"
- "La ricerca di Yang et al. dimostra che l'ordering phase consuma mediamente il 30-40% del tempo totale"
- "Nei deployment multi-datacenter o multi-cloud, la latenza di rete tra orderer nodes può dominare completamente il tempo di consenso"
- "Gli studi evidenziano che configurazioni default possono sottostimare il potenziale degli algoritmi"

**2.3 Algoritmi di Consenso Alternativi:**
- "Gli studi dimostrano che con latenze inter-nodo superiori a 50ms, le performance di Raft degradano significativamente"
- "Yang et al. misurano un throughput medio di 625-678 TPS per PBFT"

**2.4 Performance Metrics:**
- "tenendo conto delle peculiarità introdotte dalla natura distribuita"
- "Nel contesto di Hyperledger Fabric, questa metrica cattura quante transazioni il sistema riesce a processare"
- "Più affidabile risulta il throughput sostenuto, misurato su intervalli prolungati"
- "Kafka raggiunge 7,249 TPS con configurazioni default, ma questo valore può essere incrementato fino a 9,828 TPS (+35.6%)"
- "endorsement latency (tempo per esecuzione chaincode e firma), broadcast latency..."
- "I percentili, particolarmente il 95° (P95) e il 99° (P99)..."
- "Kafka con configurazioni default presenta latenza media di ~2.5s con P95 di ~105ms"
- "Yang et al. forniscono misurazioni precise: Kafka consuma mediamente il 131.6% di CPU"
- "Gli studi mostrano che l'utilizzo di memoria rimane generalmente sotto il 15%"
- "Kafka mostra un pattern caratteristico: i leader orderer nodes consumano TX bandwidth significativamente superiore (~43 Mbps)"
- "Configurazioni high-throughput (batch.size=131KB, linger.ms=25ms) raggiungono +35% TPS"
- "La latenza è inversamente proporzionale al throughput attraverso il meccanismo di batching: configurazioni che massimizzano batch.size (131KB) e linger.ms (25ms) incrementano il throughput del 35% ma aumentano la latenza del 25%"

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.1 Introduzione:**
- "le configurazioni di default garantiscono stabilità ma lasciano margini significativi di miglioramento"

**3.1.2 Analisi dell'Impatto dei Parametri:**
- "Il lavoro di Yang et al. (2022) costituisce il contributo più sistematico, applicando Design of Experiments"
- "Lo studio adotta factorial design 2³ testando batch.size (16KB vs 131KB), linger.ms (0 vs 25ms), e compression (none vs lz4)"
- "L'analisi ANOVA rivela che il 98.99% della varianza nel throughput è spiegata da questi fattori, con R²>0.98"
- "Come discusso nel dettaglio nel Cap 2.1.3, Yang et al. quantificano guadagni di throughput del 35.7%"
- "raggiungendo 9,828 TPS rispetto ai 7,249 TPS del default"
- "la natura già compatta delle transazioni blockchain (JSON/Protobuf serializzati)"

**3.2.2 Design of Experiments:**
- "Yang et al. applicano factorial design esplorando sistematicamente lo spazio parametrico"
- "Il factorial 2^k testa tutte le combinazioni di k fattori binari"
- "L'analisi ANOVA decompone la varianza in componenti attribuibili a ciascun fattore"
- "La fase di warmup (10-30 secondi) permette al sistema di raggiungere steady state"

**3.3.1 Risultati Consolidati:**
- "incrementare batch.size e linger.ms produce +35.7% throughput"
- "i parametri che controllano l'aggregazione delle transazioni emergono come i più influenti"
- "La compressione, contrariamente alle aspettative, risulta controproducente"
- "Raft e PBFT degradano significativamente con latenze >50ms"
- "L'impatto ottimale di batch.size varia con il transaction rate"

**3.3.2 Posizionamento della Tesi:**
- "Yang dimostra il potenziale di Kafka attraverso ottimizzazione"
- "allineandosi con gli standard più rigorosi"

---

## [3] APACHE SOFTWARE FOUNDATION - Kafka Documentation (2024)

### Capitolo 2 - Background e Fondamenti Teorici

**2.1 Introduzione:**
- "portando Kafka a diventare una delle tecnologie più adottate"

**2.1.1 Architettura Producer-Broker-Consumer:**
- "garantendo quello che in gergo tecnico si chiama 'disaccoppiamento temporale'"
- "fino al raggiungimento di una dimensione massima definita da batch.size, oppure fino allo scadere di un timeout controllato da linger.ms"
- "La topologia leader-follower adottata dai brokers merita particolare attenzione"
- "aggiungendo consumers a un gruppo, il carico di lavoro viene automaticamente ripartito"

**2.1.2 Replication, Partitioning:**
- "Ogni topic viene suddiviso in una o più partizioni"
- "Nel key-based partitioning, se il messaggio contiene una chiave, viene applicata una funzione hash (di default murmur2)"

**2.1.3 Parametri Critici:**
- "batch.size, che definisce la dimensione massima in bytes del batch"
- "linger.ms introduce un ulteriore grado di libertà nella configurazione"
- "Kafka supporta diversi algoritmi di compressione applicabili ai batch prima della trasmissione: none, gzip, snappy, lz4 e zstd"
- "Il parametro buffer.memory definisce la quantità totale di memoria"
- "Una formula di stima utile è buffer.memory >= batch.size × num_partitions_attive × 2"

**2.4 Performance Metrics:**
- "I producers Kafka allocano buffer proporzionali a buffer.memory"

---

## [4] CONFLUENT - Introduction to Apache Kafka (2024)

### Capitolo 2 - Background e Fondamenti Teorici

**2.1 Introduzione:**
- "i brokers gestiscono persistenza e replica, mentre i consumers recuperano i dati in modalità pull"

**2.1.1 Architettura Producer-Broker-Consumer:**
- "A quel punto l'intero batch viene trasmesso in una singola richiesta di rete"
- "All'estremo opposto, acks=all richiede la conferma da tutte le repliche configurate"
- "Ogni partizione è fisicamente rappresentata come una sequenza ordinata di segmenti di log"
- "Invece di ricevere passivamente i messaggi spinti dai brokers, i consumers richiedono attivamente i dati"
- "La persistenza degli offset, gestita nel topic interno dei consumer offsets"

**2.1.2 Replication, Partitioning:**
- "Un follower viene considerato in-sync, se mantiene una connessione attiva con Zookeeper"
- "Il meccanismo del high water mark assicura poi che i consumers leggano solo dati committed"

**2.1.3 Parametri Critici:**
- "i messaggi destinati alla stessa partizione vengono serializzati e aggiunti al buffer fino al raggiungimento di batch.size o allo scadere del timeout linger.ms"
- "Quando un messaggio viene aggiunto al batch buffer, il producer avvia un timer"
- "Quando il producer tenta di inviare un messaggio e buffer.memory è esaurita"
- "Il parametro num.io.threads controlla i thread dedicati a operazioni I/O su disco"

**2.4 Performance Metrics:**
- "Il secondo trade-off critico riguarda la relazione tra consistenza, disponibilità e performance, formalizzata dal teorema CAP"

---

## [5] THE LINUX FOUNDATION - Kafka-based Ordering Service (2023)

### Capitolo 2 - Background e Fondamenti Teorici

**2.1 Introduzione:**
- "con gli orderer nodes che fungono da relay tra il layer applicativo e il cluster di messaging"

**2.1.1 Architettura Producer-Broker-Consumer:**
- "Nel contesto di Hyperledger Fabric, gli orderer nodes operano esattamente come producers Kafka"
- "quando il leader fallisce, uno dei followers viene promosso a nuovo leader attraverso un processo di elezione coordinato da Apache Zookeeper"
- "Nei deployment di Hyperledger Fabric, il valore tipico è 3"
- "Nel contesto di Hyperledger Fabric, gli orderer nodes agiscono come consumers Kafka"

**2.1.2 Replication, Partitioning:**
- "Hyperledger Fabric adotta una configurazione apparentemente limitante: ogni canale blockchain viene mappato su un topic Kafka con una singola partizione"
- "La configurazione tipica nei deployment di produzione di Hyperledger Fabric prevede replication.factor=3 e min.insync.replicas=3"

**2.1.3 Parametri Critici:**
- "dimensionare batch.size secondo la formula batch.size (KB) = (average_tx_size × target_block_size) / 1024"
- "con batch.size=131KB e 10 canali attivi, si raccomanda buffer.memory=64MB"
- "Il parametro replica.fetch.max.bytes specifica la dimensione massima dei dati che un follower può replicare dal leader"

**2.2 Blockchain Ordering Services:**
- "Il servizio riceve transazioni già eseguite e validate dai peer endorser"
- "Kafka, disponibile dalla versione 1.0, utilizza il sistema di messaging distribuito Apache Kafka"
- "Kafka offre potenzialmente throughput elevato ma richiede gestione di cluster separato"
- "La formazione dei blocchi è controllata essenzialmente da due parametri: batch size, che definisce il numero massimo di transazioni per blocco"
- "I peer nodes, a loro volta, ricevono il blocco, validano ciascuna transazione"
- "In Kafka, il numero di repliche è configurabile attraverso il parametro min.insync.replicas"
- "Le best practice raccomandano di posizionare gli orderer nodes in regioni geograficamente vicine, con latenza di rete inferiore a 10ms"

---

## [6] THE LINUX FOUNDATION - The Ordering Service (2023)

### Capitolo 2 - Background e Fondamenti Teorici

**2.1 Introduzione:**
- "con gli orderer nodes che fungono da relay tra il layer applicativo e il cluster di messaging"

**2.1.1 Architettura:**
- "leggendo le transazioni ordinate dai brokers per costruire i blocchi che verranno poi distribuiti ai peer nodes"

**2.2 Blockchain Ordering Services:**
- "I sistemi permissioned come Hyperledger Fabric adottano invece algoritmi di consenso deterministici che offrono finalità immediata"
- "implementando il modello execute-order-validate che rappresenta una delle innovazioni più significative"
- "Questi nodi mantengono la comunicazione centrale per l'intera rete Fabric"
- "Raft, introdotto come raccomandato dalla versione 1.4, implementa il protocollo di consenso Raft direttamente tra orderer nodes"
- "Raft semplifica il deployment integrando il consenso direttamente negli orderer nodes"
- "Quando un client invia una transazione endorsata, questa viene ricevuta da uno o più orderer nodes"
- "Raft calcola automaticamente il quorum necessario come ⌈(n+1)/2⌉"

**2.3 Algoritmi di Consenso Alternativi:**
- "Raft emerge come l'algoritmo di consenso crash fault tolerant raccomandato dalla comunità Hyperledger"
- "Se un follower non riceve heartbeat entro un timeout randomizzato (election timeout)"
- "Quando riceve una transazione, il leader la aggiunge al proprio log assegnandole un indice sequenziale"
- "Il leader considera una entry committed quando ha ricevuto acknowledgment dalla maggioranza dei nodi"
- "un candidate può essere eletto leader solo se il suo log contiene tutte le entry committed"
- "Sei nodes offrono la stessa tolleranza di 5 nodes (2 fallimenti) ma con un nodo aggiuntivo"
- "tutte le transazioni devono necessariamente passare attraverso il singolo leader"

**3.3.1 Risultati Consolidati:**
- "compromesso intelligente tra performance (~300 TPS), semplicità operativa, e fault tolerance"

---

## [7] CASTRO M., LISKOV B. - PBFT (1999)

### Capitolo 2 - Background e Fondamenti Teorici

**2.3 Algoritmi di Consenso Alternativi:**
- "PBFT (Practical Byzantine Fault Tolerance) si colloca in una categoria diversa"
- "Quando un client invia una richiesta, questa viene ricevuta dal primary che assegna un sequence number"
- "Un nodo considera la richiesta prepared quando ha ricevuto prepare messages da almeno 2f+1 nodi diversi"
- "La safety property di PBFT assicura una garanzia forte"
- "Il fault tolerance di PBFT richiede n≥3f+1 nodi totali per tollerare f nodi bizantini"
- "Questo deriva dalla necessità matematica di garantire che, in ogni quorum, ci sia sempre una maggioranza strict di nodi corretti"
- "ogni nodo comunica con tutti gli altri in ciascuna fase – genera traffico di rete proporzionale a O(n²)"

---

## [8] HYPERLEDGER - Caliper (2024)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.2.1 Hyperledger Caliper:**
- "Hyperledger Caliper si è affermato come strumento standard per il benchmarking di blockchain permissioned"
- "Caliper offre architettura modulare che separa logica di generazione workload"
- "Smallbank simula transazioni bancarie, Marbles implementa asset tracking, Donothing rappresenta workload minimalista"

**3.3.2 Posizionamento della Tesi:**
- "L'utilizzo di Caliper garantisce comparabilità con la letteratura"

---

## [9] THAKKAR P., NATHAN S., VISWANATHAN B. (2018)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.1.1 Studi Comparativi:**
- "Alcuni studi si sono concentrati sul throughput massimo raggiungibile, identificando bottleneck architetturali e dimostrando che l'ordering service può diventare il collo di bottiglia principale"

---

## [10] NASIR Q. et al. (2018)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.1.1 Studi Comparativi:**
- "Altri hanno sviluppato modelli analitici per predire il throughput in funzione di parametri configurabili, sebbene le assunzioni idealizzate limitino l'applicabilità pratica"

---

## [11] SHALABY S. et al. (2020)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.1.2 Analisi dell'Impatto dei Parametri:**
- "Ricerche successive hanno dimostrato che esiste interazione complessa tra parametri di batching di Fabric e Kafka, suggerendo che l'ottimizzazione dovrebbe essere condotta congiuntamente"

**3.1.3 Gap nella Letteratura:**
- "Il lavoro di Shalaby rappresenta un'eccezione ma si limita a due layer"

**3.3.1 Risultati Consolidati:**
- "i parametri che controllano l'aggregazione delle transazioni emergono come i più influenti"
- "è stato dimostrato che ottimizzare separatamente produce risultati subottimali"

**3.3.2 Posizionamento della Tesi:**
- "indirizzando il gap sull'ottimizzazione cross-layer"
- "la letteratura ha documentato che esistono"

---

## [12] GORENFLO C. et al. (2020)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.1.2 Analisi dell'Impatto dei Parametri:**
- "Altri studi hanno esplorato come politiche di endorsement stringenti degradano il throughput non solo per overhead computazionale ma anche per interazioni con l'ordering service"

---

## [13] PONGNUMKUL S. et al. (2017)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.1.2 Analisi dell'Impatto dei Parametri:**
- "Approcci basati su machine learning per auto-tuning hanno mostrato risultati preliminari promettenti, ma con overhead computazionale ancora significativo"

---

## [14] DINH T. et al. - BLOCKBENCH (2017)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.2.1 Hyperledger Caliper:**
- "alcune ricerche hanno documentato che con più di 10-15 worker threads, Caliper satura la CPU del nodo client prima che il sistema Fabric raggiunga la sua capacità massima"

---

## [15] BALIGA A. et al. (2018)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.2.1 Hyperledger Caliper:**
- "I workload predefiniti potrebbero non riflettere caratteristiche di applicazioni reali, spingendo alcuni ricercatori a sviluppare workload custom più rappresentativi"

---

## [16] ANDROULAKI E. et al. - Fabric Paper (2018)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.2.1 Hyperledger Caliper:**
- "Le metriche di latenza end-to-end non forniscono visibilità su bottleneck interni senza strumentazione aggiuntiva che Caliper non offre nativamente"

---

## [17] MONTGOMERY D. - Design of Experiments (2017)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.2.2 Design of Experiments:**
- "Approcci frazionali possono ridurre il carico, ma al costo di non poter rilevare tutte le interazioni possibili"

---

## [18] MYERS R. et al. - Response Surface Methodology (2016)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.2.2 Design of Experiments:**
- "Metodologie più avanzate come response surface methodology permettono di mappare superfici di risposta complete, ma la complessità aumenta rapidamente"

---

## [19] SCHAD J. et al. - Noisy Neighbor (2010)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.2.3 Limiti Metodologici:**
- "Deployment su cloud pubblico introducono variabilità per interferenze di altri tenant, il cosiddetto noisy neighbor problem"

---

## [20] SOUSA J. et al. - BFT Ordering Service (2018)

### Capitolo 3 - Stato dell'Arte e Analisi Critica

**3.2.3 Limiti Metodologici:**
- "Le metriche aggregate (media, mediana) possono inoltre mascherare comportamenti patologici che impattano subset di transazioni"

---

## STATISTICHE UTILIZZO CITAZIONI

**Capitolo 2:**
- [1]: 3 occorrenze
- [2]: 25 occorrenze ⚠️ (più citato)
- [3]: 10 occorrenze
- [4]: 10 occorrenze
- [5]: 11 occorrenze
- [6]: 8 occorrenze
- [7]: 7 occorrenze

**Capitolo 3:**
- [1]: 5 occorrenze
- [2]: 15 occorrenze
- [8]: 3 occorrenze
- [9]: 1 occorrenza
- [10]: 1 occorrenza
- [11]: 4 occorrenze
- [12]: 1 occorrenza
- [13]: 1 occorrenza
- [14]: 1 occorrenza
- [15]: 1 occorrenza
- [16]: 1 occorrenza
- [17]: 1 occorrenza
- [18]: 1 occorrenza
- [19]: 1 occorrenza
- [20]: 1 occorrenza

**TOTALE CITAZIONI: 109**