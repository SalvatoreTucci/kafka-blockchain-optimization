# Dentro il container test-runner, crea uno script semplice
cat > /tmp/simple_benchmark.py << 'EOF'
#!/usr/bin/env python3
import time
import json
from kafka import KafkaProducer, KafkaConsumer
from datetime import datetime

print("Testing Kafka basic functionality...")

# Simple producer test
print("Creating producer...")
try:
    producer = KafkaProducer(
        bootstrap_servers=['kafka:29092'],
        value_serializer=lambda v: json.dumps(v).encode('utf-8')
    )
    print("Producer created successfully!")
    
    # Send test messages
    print("Sending 10 test messages...")
    start_time = time.time()
    
    for i in range(10):
        message = {
            'id': i,
            'timestamp': time.time(),
            'data': f'blockchain_transaction_{i}'
        }
        producer.send('blockchain-benchmark', value=message)
        print(f"Sent message {i+1}")
    
    producer.flush()
    producer.close()
    
    end_time = time.time()
    duration = end_time - start_time
    
    print(f"Sent 10 messages in {duration:.2f} seconds")
    print(f"Throughput: {10/duration:.2f} messages/second")
    
except Exception as e:
    print(f"Error: {e}")

print("Basic test completed!")
EOF

python /tmp/simple_benchmark.py