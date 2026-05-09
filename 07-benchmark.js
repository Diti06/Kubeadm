import http from 'k6/http';
import { check, sleep } from 'k6';

// 07-benchmark.js
// Target: Measurement Node
// Description: K6 Breakpoint test for OpenFaaS Factorial function

// The paper describes a breakpoint test:
// Concurrency increases up to 20,000 over a 30-minute period.
export const options = {
    scenarios: {
        breakpoint_test: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30m', target: 20000 }, // Ramp up to 20,000 VUs over 30 minutes
                { duration: '5m', target: 0 },      // Cool down
            ],
        },
    },
    // Optional: thresholds to fail the test early if errors go too high,
    // but a breakpoint test usually expects errors as it finds the breaking point.
    thresholds: {
        http_req_failed: ['rate<1.0'], // We expect failures at the breakpoint
    },
};

export default function () {
    // We expect the user to pass the MASTER_IP as an environment variable
    // k6 run -e MASTER_IP=192.168.1.100 07-benchmark.js
    const masterIp = __ENV.MASTER_IP;
    
    if (!masterIp) {
        throw new Error("MASTER_IP environment variable is required.");
    }

    const url = `http://${masterIp}:31112/function/factorial`;
    
    // We do a simple GET or POST request. 
    // Since our function computes factorial of 500 regardless of input, a simple GET is enough.
    const res = http.get(url, {
        timeout: '60s', // Breakpoint tests might have long queues
    });

    // Check if the response is 200 OK (successful execution)
    check(res, {
        'status is 200': (r) => r.status === 200,
        'has correct response': (r) => r.body.includes('Factorial'),
    });
    
    // Small sleep to simulate realistic user delay and not instantly kill the network card
    sleep(1);
}
