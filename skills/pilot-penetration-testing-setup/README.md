# Penetration Testing

Deploy an automated penetration testing pipeline with 4 agents that perform reconnaissance, scan for vulnerabilities, validate exploitability with safe proof-of-concept tests, and generate comprehensive pentest reports. Each agent handles a stage of the assessment -- recon, scanning, validation, and reporting -- so security assessments are methodical, thorough, and well-documented.

**Difficulty:** Advanced | **Agents:** 4

## Roles

### recon (Reconnaissance Agent)
Performs passive and active reconnaissance -- DNS enumeration, port scanning, service fingerprinting. Builds a target profile with attack surface mapping.

**Skills:** pilot-discover, pilot-stream-data, pilot-archive

### scanner (Vulnerability Scanner)
Runs automated vulnerability scans, checks CVE databases, identifies misconfigurations. Prioritizes findings by CVSS score and exploitability.

**Skills:** pilot-task-parallel, pilot-metrics, pilot-dataset

### exploiter (Exploit Validator)
Validates discovered vulnerabilities with safe proof-of-concept tests, confirms exploitability. Documents evidence and impact without causing damage.

**Skills:** pilot-task-chain, pilot-audit-log, pilot-receipt

### reporter (Pentest Reporter)
Generates penetration test reports with findings, risk ratings, remediation steps, and executive summary. Delivers to stakeholders via Slack and webhooks.

**Skills:** pilot-webhook-bridge, pilot-share, pilot-slack-bridge

## Data Flow

```
recon    --> scanner  : Recon results with target profile and services (port 1002)
scanner  --> exploiter: Vulnerability findings with CVE and severity (port 1002)
exploiter--> reporter : Validated findings with proof-of-concept evidence (port 1002)
reporter --> external : Pentest report via webhook and Slack (port 443)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `acme`).

### 1. Install skills on each server

```bash
# On server 1 (reconnaissance agent)
clawhub install pilot-discover pilot-stream-data pilot-archive
pilotctl set-hostname <your-prefix>-recon

# On server 2 (vulnerability scanner)
clawhub install pilot-task-parallel pilot-metrics pilot-dataset
pilotctl set-hostname <your-prefix>-scanner

# On server 3 (exploit validator)
clawhub install pilot-task-chain pilot-audit-log pilot-receipt
pilotctl set-hostname <your-prefix>-exploiter

# On server 4 (pentest reporter)
clawhub install pilot-webhook-bridge pilot-share pilot-slack-bridge
pilotctl set-hostname <your-prefix>-reporter
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# On recon:
pilotctl handshake <your-prefix>-scanner "setup: penetration-testing"
# On scanner:
pilotctl handshake <your-prefix>-recon "setup: penetration-testing"
# On scanner:
pilotctl handshake <your-prefix>-exploiter "setup: penetration-testing"
# On exploiter:
pilotctl handshake <your-prefix>-scanner "setup: penetration-testing"
# On exploiter:
pilotctl handshake <your-prefix>-reporter "setup: penetration-testing"
# On reporter:
pilotctl handshake <your-prefix>-exploiter "setup: penetration-testing"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-scanner — subscribe to recon results from recon:
pilotctl subscribe <your-prefix>-recon recon-result

# On <your-prefix>-exploiter — subscribe to vulnerabilities from scanner:
pilotctl subscribe <your-prefix>-scanner vulnerability

# On <your-prefix>-reporter — subscribe to validated findings from exploiter:
pilotctl subscribe <your-prefix>-exploiter validated-finding

# On <your-prefix>-recon — publish a recon result:
pilotctl publish <your-prefix>-scanner recon-result '{"target":"app.example.com","dns":["192.168.1.10"],"open_ports":[22,80,443,8080],"services":{"22":"OpenSSH 8.9","80":"nginx 1.24","8080":"Apache Tomcat 9.0.65"},"os":"Ubuntu 22.04"}'

# On <your-prefix>-scanner — publish a vulnerability:
pilotctl publish <your-prefix>-exploiter vulnerability '{"target":"app.example.com","port":8080,"cve":"CVE-2023-46589","service":"Apache Tomcat 9.0.65","severity":"critical","cvss":9.8,"description":"Request smuggling via malformed HTTP/2 frames"}'

# On <your-prefix>-exploiter — publish a validated finding:
pilotctl publish <your-prefix>-reporter validated-finding '{"target":"app.example.com","cve":"CVE-2023-46589","validated":true,"impact":"Remote code execution possible","evidence":"HTTP/2 smuggling confirmed with crafted HEADERS frame","remediation":"Upgrade Tomcat to 9.0.84+"}'

# On <your-prefix>-reporter — forward pentest report:
pilotctl publish <your-prefix>-reporter pentest-report '{"target":"app.example.com","findings_total":12,"critical":1,"high":3,"medium":5,"low":3,"executive_summary":"Critical RCE vulnerability found in Tomcat","report_url":"https://reports.example.com/pentest-2026-042"}'
```
