# Deployment progress

Tracks the resources created for this deployment. Region: **US East (N. Virginia) `us-east-1`**.

## Checklist

- [x] VPC
- [x] Subnets (4)
- [x] Internet Gateway
- [x] Route tables (public + private)
- [x] VPC settings checked (DNS hostnames, subnet CIDRs, auto-assign public IP, routes)
- [x] Security groups (ALB, EC2, RDS)
- [x] RDS: DB subnet group
- [x] RDS: MySQL instance
- [x] IAM role for EC2
- [x] EC2 instance A (`web-server-1`)
- [x] EC2 instance B (`web-server-2`)
- [x] Database schema loaded (`todo_app.Tasks`, created from `web-server-1`)
- [x] Target group
- [x] Application Load Balancer
- [x] `API_BASE_URL` set on both instances
- [x] End-to-end test (browser → ALB → EC2 → RDS: task 3 "Arabic class" created from the browser)
- [ ] Failover test

## Network

| Resource | Name | ID / value |
|---|---|---|
| VPC | `TodoAppVPC` | `vpc-06b6707f52ee4bdec` |
| VPC CIDR | | `10.0.0.0/16` |
| DNS resolution | | Enabled |
| DNS hostnames | | Enabled |
| Main route table (unused) | | `rtb-0d1548155439600a8` |
| Internet Gateway | `TodoApp-IGW` | `igw-05e27082d0ce12927` |

### Subnets

| Name | Subnet ID | AZ ID | CIDR | Auto-assign public IP | Route table |
|---|---|---|---|---|---|
| `TodoApp-Subnet-Public-A` | `subnet-073cc0a5027aa1aae` | `use1-az1` | `10.0.1.0/24` | Yes | `TodoApp-Public-Route-Table` |
| `TodoApp-Subnet-Private-A` | `subnet-0a0d7300f4062238a` | `use1-az1` | `10.0.2.0/24` | No | `TodoApp-Private-Route-Table` |
| `TodoApp-Subnet-Public-B` | `subnet-003b266e84a91355c` | `use1-az2` | `10.0.3.0/24` | Yes | `TodoApp-Public-Route-Table` |
| `TodoApp-Subnet-Private-B` | `subnet-0eee2060be21533d6` | `use1-az2` | `10.0.4.0/24` | No | `TodoApp-Private-Route-Table` |

Public-B and Private-A CIDRs are swapped compared with the architecture diagram. This has no functional effect.

### Route tables

| Name | ID | Routes | Associated subnets |
|---|---|---|---|
| `TodoApp-Public-Route-Table` | `rtb-0b174b7b3a19e163d` | `10.0.0.0/16 → local`, `0.0.0.0/0 → TodoApp-IGW` | Public-A, Public-B |
| `TodoApp-Private-Route-Table` | `rtb-01d3d1ef4c885ea20` | `10.0.0.0/16 → local` | Private-A, Private-B |

## Security groups

| Name | ID | Inbound rules | Status |
|---|---|---|---|
| `TodoApp-ALB-SG` | `sg-078a9b7932ebfb241` | HTTP 80 from `0.0.0.0/0` | Done |
| `Webserver-SG` | `sg-0afd74db774bf23d0` | Custom TCP 3000 from `TodoApp-ALB-SG`; SSH 22 from my IP (`/32`) | Done |
| `TodoApp-Database-SG` | `sg-097bca58b9000db2a` | MySQL 3306 from `Webserver-SG` | Done |
| `default` | `sg-0aba5e3012a95ca9a` | All traffic from itself | Unused |

The SSH source is the deployer's public IP. If it changes, edit the rule and select **My IP** again.

## Database

| Setting | Value | Status |
|---|---|---|
| DB identifier | `todo-instance-lab5` | Done |
| Engine | MySQL Community 8.4.11 | Done |
| Class | `db.t4g.micro` | Done |
| AZ / subnet | `us-east-1a`, `TodoApp-Subnet-Private-A` (`10.0.2.0/24`), Single-AZ | Done |
| Endpoint | `todo-instance-lab5.cmz0eoi66au7.us-east-1.rds.amazonaws.com` | Done |
| Port | `3306` | Done |
| Master username | `admin` | Done |
| Security group | `TodoApp-Database-SG` (`sg-097bca58b9000db2a`) | Done |
| Internet access gateway | Disabled | Done |
| DB subnet group | `default-vpc-06b6707f52ee4bdec`: Private-A (`10.0.2.0/24`), Private-B (`10.0.4.0/24`) | Done (public subnets removed) |
| Publicly accessible | No (endpoint resolves to private IP `10.0.2.246`) | Done |
| TLS required (`require_secure_transport`) | `0` (app connects without TLS) | Verified |
| Connectivity from `web-server-1` | Connected with mysql2 | Verified |

## Compute

| Resource | Name | Details | Status |
|---|---|---|---|
| IAM role + instance profile | `TodoApp-EC2-Role` | Trusted entity `ec2.amazonaws.com`; policy `AmazonSSMManagedInstanceCore` | Done |
| EC2 instance A | `web-server-1` (`i-0f0b672e59080290d`) | AL2023, `t3.micro`, Public-A (`us-east-1a`), private IP `10.0.1.123`, `Webserver-SG`, `TodoApp-EC2-Role`, key pair `web-server-1` | Running; app at `~/todo-app` (symlink to `~/repo/projects/intermediate/project5`), `todo-app` systemd service active, `/tasks` and `/` verified |
| EC2 instance B | `web-server-2` (`i-0f9426a3b4a556964`) | AL2023, `t3.micro`, Public-B (`us-east-1b`), private IP `10.0.3.137`, `Webserver-SG`, `TodoApp-EC2-Role`, key pair `web-server-2` | Running; app at `~/todo-app`, `todo-app` service active; reads task 1 written by `web-server-1` (shared RDS verified) |
| Extra instance | `Bastion-connect` (`i-09fd828a8444ecb45`) | Not part of the architecture | Being terminated |

## Load balancer

| Resource | Name | Details | Status |
|---|---|---|---|
| Target group | `TodoApp-TG` (`targetgroup/TodoApp-TG/4b156e7a22e36878`) | Instances, HTTP `3000`, VPC `TodoAppVPC`; health check `/` (healthy/unhealthy threshold 2, interval 10s, success code 200); targets `web-server-1:3000`, `web-server-2:3000` | Done (targets Unused until an ALB is attached) |
| Application Load Balancer | `TodoApp-ALB` (`app/TodoApp-ALB/6cfb57233112b5bf`) | Internet-facing, IPv4, Public-A (`subnet-073cc0a5027aa1aae`) + Public-B (`subnet-003b266e84a91355c`), `TodoApp-ALB-SG`, listener HTTP 80 → `TodoApp-TG` | Active |
| ALB DNS name | | `TodoApp-ALB-933813589.us-east-1.elb.amazonaws.com` | `GET /` → 200, `GET /tasks` returns tasks 1 and 2 |
| `API_BASE_URL` | Both instances | `http://TodoApp-ALB-933813589.us-east-1.elb.amazonaws.com` | `GET /config` returns it from both targets |
