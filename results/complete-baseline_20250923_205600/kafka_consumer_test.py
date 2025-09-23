import time
import json
from kafka import KafkaConsumer
from kafka.errors import KafkaError

def run_consumer_test():
    consumer_config = {
        'bootstrap_servers': ['localhost:9092'],
        'auto_offset_reset': 'earliest',
        'enable_auto_commit': True,
        'group_id': 'test-group',
        'value_deserializer': lambda m: json.loads(m.decode('utf-8'))
    }
    
    consumer = KafkaConsumer('test-topic', **consumer_config)
    
    messages_consumed = 0
    start_time = time.time()
    test_duration = 30  # 30 secondi per consumer
    latencies = []
    
    print(f"Starting consumer test for {test_duration} seconds...")
    
    for message in consumer:
        current_time = time.time()
        
        if current_time - start_time > test_duration:
            break
            
        messages_consumed += 1
        
        # Calcola latency se possibile
        if 'timestamp' in message.value:
            latency = (current_time - message.value['timestamp']) * 1000  # ms
            latencies.append(latency)
        
        if messages_consumed % 50 == 0:
            elapsed = current_time - start_time
            rate = messages_consumed / elapsed if elapsed > 0 else 0
            print(f"Messages consumed: {messages_consumed}, Rate: {rate:.2f} msgs/sec")
    
    consumer.close()
    
    total_time = time.time() - start_time
    avg_throughput = messages_consumed / total_time if total_time > 0 else 0
    avg_latency = sum(latencies) / len(latencies) if latencies else 0
    
    results = {
        'total_messages': messages_consumed,
        'test_duration': total_time,
        'avg_throughput': avg_throughput,
        'avg_latency_ms': avg_latency
    }
    
    print(f"\n=== CONSUMER RESULTS ===")
    print(f"Messages consumed: {messages_consumed}")
    print(f"Test duration: {total_time:.2f} seconds")
    print(f"Average throughput: {avg_throughput:.2f} msgs/sec")
    print(f"Average latency: {avg_latency:.2f} ms")
    
    return results

if __name__ == "__main__":
    results = run_consumer_test()
    with open('/workspace/results/consumer_results.json', 'w') as f:
        json.dump(results, f, indent=2)
