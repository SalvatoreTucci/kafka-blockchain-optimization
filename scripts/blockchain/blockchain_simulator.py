#!/usr/bin/env python3
"""
Simple Blockchain Simulator for Kafka Ordering Service Testing
Simulates: Transaction submission -> Kafka ordering -> Block formation -> Validation
"""

import time
import json
import hashlib
from dataclasses import dataclass, asdict
from typing import List, Dict
from kafka import KafkaProducer, KafkaConsumer
from kafka.errors import KafkaError

@dataclass
class Transaction:
    """Blockchain transaction"""
    tx_id: str
    from_addr: str
    to_addr: str
    amount: float
    timestamp: float
    nonce: int
    
    def to_dict(self):
        return asdict(self)
    
    def hash(self) -> str:
        """Calculate transaction hash"""
        tx_string = json.dumps(self.to_dict(), sort_keys=True)
        return hashlib.sha256(tx_string.encode()).hexdigest()

@dataclass
class Block:
    """Blockchain block"""
    block_number: int
    timestamp: float
    transactions: List[Transaction]
    previous_hash: str
    block_hash: str = ""
    
    def calculate_hash(self) -> str:
        """Calculate block hash"""
        tx_hashes = [tx.hash() for tx in self.transactions]
        block_data = {
            'block_number': self.block_number,
            'timestamp': self.timestamp,
            'transactions': tx_hashes,
            'previous_hash': self.previous_hash
        }
        block_string = json.dumps(block_data, sort_keys=True)
        return hashlib.sha256(block_string.encode()).hexdigest()
    
    def finalize(self):
        """Finalize block by calculating hash"""
        self.block_hash = self.calculate_hash()

class BlockchainLedger:
    """Simple blockchain ledger"""
    def __init__(self):
        self.chain: List[Block] = []
        self.create_genesis_block()
    
    def create_genesis_block(self):
        """Create genesis block"""
        genesis = Block(
            block_number=0,
            timestamp=time.time(),
            transactions=[],
            previous_hash="0" * 64
        )
        genesis.finalize()
        self.chain.append(genesis)
    
    def get_last_block(self) -> Block:
        """Get last block in chain"""
        return self.chain[-1]
    
    def add_block(self, block: Block) -> bool:
        """Add block to chain with validation"""
        # Validate previous hash
        if block.previous_hash != self.get_last_block().block_hash:
            return False
        
        # Validate block number
        if block.block_number != len(self.chain):
            return False
        
        # Finalize and add
        block.finalize()
        self.chain.append(block)
        return True
    
    def get_chain_length(self) -> int:
        return len(self.chain)

class OrderingService:
    """Kafka-based ordering service"""
    def __init__(self, bootstrap_servers='kafka:29092', 
                 batch_size=16384, linger_ms=0, compression_type=None):
        
        self.bootstrap_servers = bootstrap_servers
        self.topic = 'blockchain-ordering'
        
        # Producer config (to be optimized)
        self.producer_config = {
            'bootstrap_servers': [bootstrap_servers],
            'value_serializer': lambda v: json.dumps(v).encode('utf-8'),
            'key_serializer': lambda v: str(v).encode('utf-8'),
            'batch_size': batch_size,
            'linger_ms': linger_ms,
            'acks': 'all',
            'retries': 3,
            'max_in_flight_requests_per_connection': 5
        }
        
        if compression_type and compression_type != 'none':
            self.producer_config['compression_type'] = compression_type
        
        self.producer = None
        self.consumer = None
        
    def connect_producer(self):
        """Initialize producer"""
        self.producer = KafkaProducer(**self.producer_config)
        
    def connect_consumer(self, group_id='blockchain-peer'):
        """Initialize consumer"""
        self.consumer = KafkaConsumer(
            self.topic,
            bootstrap_servers=[self.bootstrap_servers],
            value_deserializer=lambda v: json.loads(v.decode('utf-8')),
            group_id=group_id,
            auto_offset_reset='earliest',
            enable_auto_commit=True
        )
    
    def submit_transaction(self, tx: Transaction):
        """Submit transaction to ordering service"""
        future = self.producer.send(
            self.topic,
            key=tx.tx_id,
            value=tx.to_dict()
        )
        return future
    
    def close(self):
        """Close connections"""
        if self.producer:
            self.producer.flush()
            self.producer.close()
        if self.consumer:
            self.consumer.close()

class BlockchainPeer:
    """Blockchain peer that validates and commits blocks"""
    def __init__(self, peer_id: str, ordering_service: OrderingService, 
                 block_size=100, block_timeout=3.0):
        self.peer_id = peer_id
        self.ordering_service = ordering_service
        self.ledger = BlockchainLedger()
        self.pending_transactions: List[Transaction] = []
        
        self.block_size = block_size
        self.block_timeout = block_timeout
        self.last_block_time = time.time()
        
        # Metrics
        self.blocks_created = 0
        self.transactions_processed = 0
        self.block_formation_times = []
        
    def should_create_block(self) -> bool:
        """Check if should create new block"""
        time_elapsed = time.time() - self.last_block_time
        
        # Create block if: enough transactions OR timeout reached
        return (len(self.pending_transactions) >= self.block_size or 
                (len(self.pending_transactions) > 0 and time_elapsed >= self.block_timeout))
    
    def create_block(self) -> Block:
        """Create new block from pending transactions"""
        block_start = time.time()
        
        # Take transactions for block
        txs_for_block = self.pending_transactions[:self.block_size]
        self.pending_transactions = self.pending_transactions[self.block_size:]
        
        # Create block
        last_block = self.ledger.get_last_block()
        new_block = Block(
            block_number=self.ledger.get_chain_length(),
            timestamp=time.time(),
            transactions=txs_for_block,
            previous_hash=last_block.block_hash
        )
        
        # Add to ledger
        if self.ledger.add_block(new_block):
            self.blocks_created += 1
            self.transactions_processed += len(txs_for_block)
            
            block_time = time.time() - block_start
            self.block_formation_times.append(block_time)
            
            self.last_block_time = time.time()
            return new_block
        
        return None
    
    def process_ordered_transactions(self, max_messages=None):
        """Process transactions from ordering service"""
        self.ordering_service.connect_consumer(group_id=f'peer-{self.peer_id}')
        
        messages_processed = 0
        
        for message in self.ordering_service.consumer:
            # Reconstruct transaction
            tx_data = message.value
            tx = Transaction(**tx_data)
            
            # Add to pending
            self.pending_transactions.append(tx)
            messages_processed += 1
            
            # Create block if criteria met
            if self.should_create_block():
                block = self.create_block()
                if block:
                    print(f"[Peer {self.peer_id}] Created block {block.block_number} "
                          f"with {len(block.transactions)} transactions")
            
            # Stop if reached limit
            if max_messages and messages_processed >= max_messages:
                break
        
        # Create final block if pending transactions remain
        if self.pending_transactions:
            self.create_block()
    
    def get_metrics(self) -> Dict:
        """Get peer metrics"""
        avg_block_time = (sum(self.block_formation_times) / len(self.block_formation_times) 
                         if self.block_formation_times else 0)
        
        return {
            'peer_id': self.peer_id,
            'blocks_created': self.blocks_created,
            'transactions_processed': self.transactions_processed,
            'chain_length': self.ledger.get_chain_length(),
            'avg_block_formation_time_ms': avg_block_time * 1000,
            'pending_transactions': len(self.pending_transactions)
        }

def create_sample_transaction(tx_id: int) -> Transaction:
    """Create sample blockchain transaction"""
    return Transaction(
        tx_id=f"tx_{tx_id:06d}",
        from_addr=f"0x{(tx_id * 13) % 1000000:06x}",
        to_addr=f"0x{(tx_id * 17) % 1000000:06x}",
        amount=100.0 + (tx_id % 1000),
        timestamp=time.time(),
        nonce=tx_id
    )

if __name__ == "__main__":
    print("Blockchain Simulator - Component Test")
    
    # Test ledger
    ledger = BlockchainLedger()
    print(f"Genesis block: {ledger.get_last_block().block_hash[:16]}...")
    
    # Test transaction
    tx = create_sample_transaction(1)
    print(f"Sample transaction: {tx.tx_id} -> {tx.hash()[:16]}...")
    
    print("Blockchain simulator components loaded successfully")
