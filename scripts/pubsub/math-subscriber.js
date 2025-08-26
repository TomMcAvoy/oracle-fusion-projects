#!/usr/bin/env node
/**
 * Math Subscriber - Subscribes to math-requested events
 * Demonstrates the pub/sub pattern with JavaScript orchestration
 */

const { spawn, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ACTION_ID = process.argv[2] || 'test-action-' + Date.now();
const SCRIPT_DIR = __dirname;
const SUBSCRIBER_ID = `math-subscriber-${process.pid}`;

console.log(`🧮 Math subscriber starting for action: ${ACTION_ID}`);

// Subscription patterns
const SUBSCRIBE_PATTERNS = [
    `math-requested:${ACTION_ID}`,
    `math-retry:${ACTION_ID}`,
    `test-requested:${ACTION_ID}`
];

/**
 * Process math computation message
 */
function processMathMessage(message) {
    console.log(`📨 Processing math message: ${message}`);
    
    try {
        const parts = message.split(':');
        const actionId = parts[0];
        const eventType = parts[1];
        const timestamp = parts[2];
        const payload = JSON.parse(parts[3] || '{}');
        
        console.log(`📋 Event: ${eventType} | Payload:`, payload);
        
        switch (eventType) {
            case 'math-requested':
            case 'test-requested':
            case 'math-retry':
                return executeMathAction(payload);
            default:
                console.log(`❓ Unknown event type: ${eventType}`);
                return Promise.reject(new Error(`Unknown event type: ${eventType}`));
        }
    } catch (error) {
        console.error(`❌ Message parsing failed:`, error);
        return Promise.reject(error);
    }
}

/**
 * Execute math computation with output streaming
 */
async function executeMathAction(payload) {
    const operation = payload.operation || 'fibonacci';
    const iterations = payload.iterations || 50;
    const jobId = payload.job_id || process.env.GITHUB_RUN_ID || 'test-job';
    
    console.log(`🧮 Executing math action: ${operation} with ${iterations} iterations`);
    
    // Publish started event
    publishEvent('math-started', {
        subscriber_id: SUBSCRIBER_ID,
        started_at: new Date().toISOString(),
        operation,
        iterations,
        job_id: jobId
    });
    
    try {
        // Execute math processor with output streaming
        const mathProcessorPath = path.join(SCRIPT_DIR, '..', 'pipeline', 'math-processor.js');
        const outputStreamerPath = path.join(SCRIPT_DIR, 'output-streamer.sh');
        
        // Build command for output streamer
        const command = `node "${mathProcessorPath}" "${operation}" "${iterations}" "${jobId}" "${ACTION_ID}"`;
        
        console.log(`🚰 Starting math processing with output streaming...`);
        console.log(`📝 Command: ${command}`);
        
        // Execute with output streaming
        const result = await executeWithStreaming(outputStreamerPath, ACTION_ID, 'math', command);
        
        if (result.exitCode === 0) {
            console.log(`✅ Math processing completed successfully`);
            
            publishEvent('math-completed', {
                subscriber_id: SUBSCRIBER_ID,
                completed_at: new Date().toISOString(),
                result: 'success',
                operation,
                iterations,
                job_id: jobId
            });
            
            return true;
        } else if (result.exitCode === 42) {
            console.log(`⚠️  Math processing escaped gracefully`);
            
            publishEvent('math-escaped', {
                subscriber_id: SUBSCRIBER_ID,
                escaped_at: new Date().toISOString(),
                reason: 'graceful_escape',
                operation,
                iterations,
                job_id: jobId
            });
            
            return true; // Escape is considered success
        } else {
            throw new Error(`Math processing failed with exit code: ${result.exitCode}`);
        }
        
    } catch (error) {
        console.error(`❌ Math processing failed:`, error);
        
        publishEvent('math-failed', {
            subscriber_id: SUBSCRIBER_ID,
            failed_at: new Date().toISOString(),
            error: error.message,
            operation,
            iterations,
            job_id: jobId
        });
        
        throw error;
    }
}

/**
 * Execute command with output streaming
 */
function executeWithStreaming(streamerScript, actionId, stage, command) {
    return new Promise((resolve, reject) => {
        console.log(`🚰 Executing: ${streamerScript} ${actionId} ${stage} "${command}"`);
        
        const child = spawn('bash', [streamerScript, actionId, stage, command], {
            stdio: 'inherit',
            shell: true
        });
        
        child.on('close', (code) => {
            console.log(`📊 Streaming process exited with code: ${code}`);
            resolve({ exitCode: code });
        });
        
        child.on('error', (error) => {
            console.error(`❌ Streaming process error:`, error);
            reject(error);
        });
        
        // Timeout after 5 minutes
        const timeout = setTimeout(() => {
            console.log(`⏰ Math processing timed out - killing process`);
            child.kill('SIGTERM');
            setTimeout(() => child.kill('SIGKILL'), 5000);
            resolve({ exitCode: 124 }); // Timeout exit code
        }, 300000);
        
        child.on('close', () => {
            clearTimeout(timeout);
        });
    });
}

/**
 * Publish event using the publisher script
 */
function publishEvent(eventType, data) {
    try {
        const publisherScript = path.join(SCRIPT_DIR, 'publisher.sh');
        const payload = JSON.stringify(data);
        
        execSync(`"${publisherScript}" "${ACTION_ID}" "${eventType}" '${payload}'`, {
            stdio: 'inherit'
        });
    } catch (error) {
        console.error(`❌ Failed to publish ${eventType} event:`, error);
    }
}

/**
 * Redis subscription (primary method)
 */
async function subscribeRedis() {
    console.log(`📡 Starting Redis subscriber...`);
    
    return new Promise((resolve, reject) => {
        const patterns = SUBSCRIBE_PATTERNS.join(' ');
        const child = spawn('redis-cli', ['PSUBSCRIBE', ...SUBSCRIBE_PATTERNS], {
            stdio: 'pipe'
        });
        
        child.stdout.on('data', (data) => {
            const lines = data.toString().split('\n');
            
            for (const line of lines) {
                if (line.includes('pmessage')) {
                    // Parse Redis pmessage format
                    const parts = line.split('\n');
                    if (parts.length >= 4) {
                        const message = parts[3];
                        console.log(`📥 Received Redis message: ${message}`);
                        
                        processMathMessage(message)
                            .then(() => {
                                console.log(`✅ Message processed successfully`);
                                resolve(true);
                            })
                            .catch((error) => {
                                console.error(`❌ Message processing failed:`, error);
                                reject(error);
                            });
                        
                        return;
                    }
                }
            }
        });
        
        child.on('error', (error) => {
            console.error(`❌ Redis subscriber error:`, error);
            reject(error);
        });
        
        // Timeout after 10 minutes
        setTimeout(() => {
            console.log(`⏰ Redis subscription timed out`);
            child.kill();
            reject(new Error('Subscription timeout'));
        }, 600000);
    });
}

/**
 * File-based subscription (fallback method)
 */
async function subscribeFile() {
    console.log(`📁 Starting file-based subscriber...`);
    
    const messageDir = '/tmp/pipeline-messages';
    const actionDir = path.join(messageDir, ACTION_ID);
    const processedFile = `/tmp/math-processed-${ACTION_ID}`;
    
    const maxWait = 300000; // 5 minutes
    const interval = 2000;   // 2 seconds
    let elapsed = 0;
    
    while (elapsed < maxWait) {
        for (const pattern of SUBSCRIBE_PATTERNS) {
            const eventType = pattern.split(':')[0];
            const eventFile = path.join(actionDir, `${eventType}.json`);
            
            if (fs.existsSync(eventFile) && !fs.existsSync(processedFile)) {
                console.log(`📥 Found event file: ${eventFile}`);
                
                try {
                    const message = fs.readFileSync(eventFile, 'utf8');
                    fs.writeFileSync(processedFile, ''); // Mark as processed
                    
                    await processMathMessage(message);
                    console.log(`✅ File-based message processed successfully`);
                    return true;
                } catch (error) {
                    console.error(`❌ File-based message processing failed:`, error);
                    throw error;
                }
            }
        }
        
        await new Promise(resolve => setTimeout(resolve, interval));
        elapsed += interval;
    }
    
    throw new Error(`File-based subscriber timed out after ${maxWait}ms`);
}

/**
 * Main subscription logic
 */
async function main() {
    // Set up signal handlers
    process.on('SIGINT', () => {
        console.log(`🛑 Math subscriber interrupted`);
        process.exit(130);
    });
    
    process.on('SIGTERM', () => {
        console.log(`🛑 Math subscriber terminated`);
        process.exit(143);
    });
    
    console.log(`🎯 Subscribing to patterns: ${SUBSCRIBE_PATTERNS.join(', ')}`);
    
    try {
        // Try Redis first
        try {
            execSync('redis-cli ping', { stdio: 'ignore' });
            await subscribeRedis();
            console.log(`🎉 Redis subscription completed`);
            return;
        } catch (error) {
            console.log(`❌ Redis subscription failed, falling back to file-based: ${error.message}`);
        }
        
        // Fallback to file-based
        await subscribeFile();
        console.log(`🎉 File-based subscription completed`);
        
    } catch (error) {
        console.error(`💥 All subscription methods failed:`, error);
        process.exit(1);
    }
}

// Start the subscriber
main();