#!/usr/bin/env node
/**
 * Math Processor - Test Action for Async Pipeline
 * Performs mathematical computations while demonstrating:
 * - Correlation ID tracking
 * - Structured output for indexing
 * - Progress reporting
 * - Escape mechanisms
 */

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const operation = args[0] || 'fibonacci';
const iterations = parseInt(args[1]) || 100;
const jobId = args[2] || 'unknown-job';
const actionId = args[3] || 'unknown-action';

// Generate correlation ID
const correlationId = `${jobId}-${actionId}-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;

console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level: 'INFO',
    correlation_id: correlationId,
    job_id: jobId,
    action_id: actionId,
    event: 'processor_started',
    operation: operation,
    iterations: iterations,
    message: `🧮 Math processor started: ${operation} with ${iterations} iterations`
}));

// Progress tracking
let processedCount = 0;
let results = [];

// Escape mechanism - check for stop file
const stopFile = `/tmp/stop-${actionId}`;
const checkEscape = () => {
    if (fs.existsSync(stopFile)) {
        console.log(JSON.stringify({
            timestamp: new Date().toISOString(),
            level: 'WARN',
            correlation_id: correlationId,
            job_id: jobId,
            action_id: actionId,
            event: 'graceful_escape',
            processed_count: processedCount,
            message: '⚠️  Escape file detected - graceful shutdown'
        }));
        process.exit(42); // Special escape code
    }
};

// Progress reporter
const reportProgress = (current, total, result = null) => {
    const percentage = Math.round((current / total) * 100);
    console.log(JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'INFO',
        correlation_id: correlationId,
        job_id: jobId,
        action_id: actionId,
        event: 'progress_update',
        processed: current,
        total: total,
        percentage: percentage,
        result: result,
        message: `📊 Progress: ${current}/${total} (${percentage}%)`
    }));
};

// Mathematical operations
const operations = {
    fibonacci: (n) => {
        if (n <= 1) return n;
        let a = 0, b = 1, temp;
        for (let i = 2; i <= n; i++) {
            temp = a + b;
            a = b;
            b = temp;
        }
        return b;
    },
    
    prime: (n) => {
        if (n < 2) return false;
        for (let i = 2; i <= Math.sqrt(n); i++) {
            if (n % i === 0) return false;
        }
        return true;
    },
    
    factorial: (n) => {
        if (n <= 1) return 1;
        let result = 1;
        for (let i = 2; i <= n; i++) {
            result *= i;
        }
        return result;
    },
    
    hash: (input) => {
        return crypto.createHash('sha256').update(String(input)).digest('hex');
    },
    
    async_simulation: async (duration) => {
        return new Promise(resolve => {
            setTimeout(() => {
                resolve(`Async operation completed after ${duration}ms`);
            }, duration);
        });
    }
};

// Main processor function
async function processOperations() {
    try {
        console.log(JSON.stringify({
            timestamp: new Date().toISOString(),
            level: 'INFO',
            correlation_id: correlationId,
            job_id: jobId,
            action_id: actionId,
            event: 'processing_started',
            message: `🚀 Starting ${operation} operations`
        }));

        for (let i = 1; i <= iterations; i++) {
            // Check for escape conditions
            checkEscape();
            
            let result;
            const startTime = Date.now();
            
            switch (operation) {
                case 'fibonacci':
                    result = operations.fibonacci(i);
                    break;
                case 'prime':
                    result = operations.prime(i) ? `${i} is prime` : `${i} is composite`;
                    break;
                case 'factorial':
                    result = i <= 10 ? operations.factorial(i) : 'too large';
                    break;
                case 'hash':
                    result = operations.hash(i).substring(0, 16);
                    break;
                case 'async':
                    result = await operations.async_simulation(Math.random() * 100);
                    break;
                default:
                    result = `Unknown operation: ${operation}`;
            }
            
            const processingTime = Date.now() - startTime;
            processedCount++;
            results.push({ input: i, result, processingTime });
            
            // Report progress every 10% or every 10 iterations (whichever is smaller)
            const reportInterval = Math.min(10, Math.max(1, Math.floor(iterations / 10)));
            if (i % reportInterval === 0 || i === iterations) {
                reportProgress(i, iterations, result);
            }
            
            // Simulate realistic processing delay
            if (operation === 'async') {
                await new Promise(resolve => setTimeout(resolve, 10));
            }
            
            // Memory management for large iterations
            if (results.length > 1000) {
                results = results.slice(-100); // Keep last 100 results
            }
        }
        
        // Generate final statistics
        const totalTime = results.reduce((sum, r) => sum + r.processingTime, 0);
        const avgTime = totalTime / results.length;
        const maxTime = Math.max(...results.map(r => r.processingTime));
        const minTime = Math.min(...results.map(r => r.processingTime));
        
        console.log(JSON.stringify({
            timestamp: new Date().toISOString(),
            level: 'INFO',
            correlation_id: correlationId,
            job_id: jobId,
            action_id: actionId,
            event: 'processing_completed',
            statistics: {
                total_processed: processedCount,
                total_time_ms: totalTime,
                avg_time_ms: avgTime,
                max_time_ms: maxTime,
                min_time_ms: minTime,
                operations_per_second: (processedCount * 1000) / totalTime
            },
            message: `✅ Successfully processed ${processedCount} ${operation} operations`
        }));
        
        // Save results summary
        const summaryFile = `/tmp/math-results-${actionId}.json`;
        const summary = {
            correlation_id: correlationId,
            job_id: jobId,
            action_id: actionId,
            operation: operation,
            iterations: iterations,
            processed_count: processedCount,
            statistics: {
                total_time_ms: totalTime,
                avg_time_ms: avgTime,
                operations_per_second: (processedCount * 1000) / totalTime
            },
            sample_results: results.slice(-10), // Last 10 results
            completed_at: new Date().toISOString()
        };
        
        fs.writeFileSync(summaryFile, JSON.stringify(summary, null, 2));
        
        console.log(JSON.stringify({
            timestamp: new Date().toISOString(),
            level: 'INFO',
            correlation_id: correlationId,
            job_id: jobId,
            action_id: actionId,
            event: 'summary_saved',
            summary_file: summaryFile,
            message: `📄 Results summary saved to ${summaryFile}`
        }));
        
    } catch (error) {
        console.error(JSON.stringify({
            timestamp: new Date().toISOString(),
            level: 'ERROR',
            correlation_id: correlationId,
            job_id: jobId,
            action_id: actionId,
            event: 'processing_error',
            error: error.message,
            stack: error.stack,
            message: `❌ Processing failed: ${error.message}`
        }));
        process.exit(1);
    }
}

// Handle process signals for graceful shutdown
process.on('SIGTERM', () => {
    console.log(JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'WARN',
        correlation_id: correlationId,
        job_id: jobId,
        action_id: actionId,
        event: 'sigterm_received',
        processed_count: processedCount,
        message: '⚠️  SIGTERM received - graceful shutdown'
    }));
    process.exit(42);
});

process.on('SIGINT', () => {
    console.log(JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'WARN',
        correlation_id: correlationId,
        job_id: jobId,
        action_id: actionId,
        event: 'sigint_received',
        processed_count: processedCount,
        message: '⚠️  SIGINT received - graceful shutdown'
    }));
    process.exit(130);
});

// Start processing
console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level: 'INFO',
    correlation_id: correlationId,
    job_id: jobId,
    action_id: actionId,
    event: 'processor_initialized',
    node_version: process.version,
    platform: process.platform,
    memory_usage: process.memoryUsage(),
    message: '🔧 Math processor initialized'
}));

processOperations();