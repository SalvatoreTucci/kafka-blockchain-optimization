import time
import json
from kafka import KafkaProducer
from kafka.errors import KafkaError

def run_producer_test():
    producer_config = {
        'bootstrap_servers': ['localhost:9092'],
        'batch_size': 16384,
        'linger_ms': 0,
        'buffer_memory': 33554432,
        'value_serializer': lambda x: json.dumps(x).encode('utf-8')
    }
    
    producer = KafkaProducer(**producer_config)
    
    messages_sent = 0
    start_time = time.time()
    test_duration = 60  # 1 minuto di test
    
    print(f"Starting producer test for {test_duration} seconds...")
    
    while time.time() - start_time < test_duration:
        message = {
            'timestamp': time.time(),
            'message_id': messages_sent,
            'data': f'test_message_{messages_sent}'
        }
        
        try:
            future = producer.send('test-topic', message)
            future.get(timeout=10)  # Wait for confirmation
            messages_sent += 1
            
            if messages_sent % 100 == 0:
                elapsed = time.time() - start_time
                rate = messages_sent / elapsed
                print(f"Messages sent: {messages_sent}, Rate: {rate:.2f} msgs/sec")
                
        except KafkaError as e:
            print(f"Error sending message: {e}")
    
    producer.flush()
    producer.close()
    
    total_time = time.time() - start_time
    avg_throughput = messages_sent / total_time
    
    results = {
        'total_messages': messages_sent,
        'test_duration': total_time,
        'avg_throughput': avg_throughput,
        'target_throughput': 500
    }
    
    print(f"\n=== RESULTS ===")
    print(f"Messages sent: {messages_sent}")
    print(f"Test duration: {total_time:.2f} seconds")
    print(f"Average throughput: {avg_throughput:.2f} msgs/sec")
    
    return results

if __name__ == "__main__":
    results = run_producer_test()
    with open('/workspace/results/producer_results.json', 'w') as f:
        json.dump(results, f, indent=2)
