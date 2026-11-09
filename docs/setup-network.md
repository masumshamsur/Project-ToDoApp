# Set up the network (VPC, subnets, route tables, security groups)

This guide creates the network that every other component runs in. Use the same Region (`us-east-1`) throughout the project.

If something doesn't match, see [troubleshooting.md](troubleshooting.md).

## 1. Create the VPC and subnets

1. Open the **VPC** console, go to **Your VPCs** and choose **Create VPC**.
2. Choose **VPC only**:
   - **Name:** `TodoAppVPC`
   - **IPv4 CIDR:** `10.0.0.0/16`
   - **IPv6 CIDR block:** none
   - **Tenancy:** Default
3. Select the VPC, choose **Actions → Edit VPC settings**, check **Enable DNS hostnames** and save.

   The VPC **Details** panel should show **DNS resolution: Enabled** and **DNS hostnames: Enabled** (see the screenshot in [4. Check the VPC](#4-check-the-vpc)).

   > **Why enable DNS hostnames?** A VPC has two DNS settings:
   >
   > - **DNS resolution** (on by default) lets resources in the VPC look up names through the Amazon DNS server. The web servers need it to turn the RDS endpoint (`todo-instance-lab5.<id>.us-east-1.rds.amazonaws.com`) into the database's private IP.
   > - **DNS hostnames** (off by default in a VPC you create yourself) gives instances DNS names, such as `ec2-3-91-204-88.compute-1.amazonaws.com` for an instance with a public IP.
   >
   > Turning on DNS hostnames makes your VPC behave like the default VPC. Several AWS features need both settings on:
   >
   > - an RDS instance with **Public access: Yes**
   > - **interface VPC endpoints with private DNS**, such as the SSM endpoints Session Manager would need if the web servers moved to private subnets
   > - Route 53 **private hosted zones**
   >
   > This build would still work without it, because the app reaches RDS through DNS resolution. Turn it on anyway, so you don't hit these limits later.

4. Go to **Subnets → Create subnet** and select `TodoAppVPC`. Fill in the first subnet, then choose **Add new subnet** for each of the others. The CIDRs match the architecture diagram:

   | Name | Availability Zone | CIDR |
   |---|---|---|
   | `TodoApp-Subnet-Public-A` | `us-east-1a` | `10.0.1.0/24` |
   | `TodoApp-Subnet-Public-B` | `us-east-1b` | `10.0.2.0/24` |
   | `TodoApp-Subnet-Private-A` | `us-east-1a` | `10.0.3.0/24` |
   | `TodoApp-Subnet-Private-B` | `us-east-1b` | `10.0.4.0/24` |

   ![Subnets list filtered by TodoAppVPC: Public-A 10.0.1.0/24 and Private-A 10.0.3.0/24 in us-east-1a, Public-B 10.0.2.0/24 and Private-B 10.0.4.0/24 in us-east-1b. Public-A details show auto-assign public IPv4 Yes and the public route table](images/r2-02-subnets.png)

5. For each **public** subnet, choose **Actions → Edit subnet settings**, enable **Auto-assign public IPv4 address** and save. Leave this off for the private subnets.

   > **Why auto-assign a public IPv4 address?** The route `0.0.0.0/0 → IGW` alone doesn't put an instance on the internet. The internet gateway only translates between an instance's private IP and a **public IP**, so an instance without a public IP can't reach the internet or be reached from it, even in a public subnet.
   >
   > The web servers need internet access for:
   >
   > - **SSH** from your computer
   > - **Installing software**: `dnf install nodejs`, `git clone` from GitHub and `npm install` all download from the internet
   > - **Session Manager**: the SSM agent on the instance connects out to the AWS Systems Manager service
   >
   > With this setting on, every instance launched in the subnet gets a public IP automatically, so you can't forget to turn it on in the launch wizard.
   >
   > Leave it **off** for the private subnets. The database should never have a public IP, and the private route table has no route to the internet anyway. The ALB doesn't depend on this setting either, because it gets its own public IPs.
   >
   > **Good to know:**
   > - A public IP changes when you stop and start the instance. Use an Elastic IP if you need a fixed one.
   > - AWS charges about $0.005 per hour (around $3.60 a month) for each public IPv4 address. The free tier covers 750 hours a month for the first 12 months.

## 2. Create the Internet Gateway

1. Go to **Internet gateways → Create internet gateway** and name it `TodoApp-IGW`.
2. Choose **Actions → Attach to VPC** and select `TodoAppVPC`.

## 3. Create the route tables

**Public route table**

1. **Route tables → Create route table**: name `TodoApp-Public-Route-Table`, VPC `TodoAppVPC`.
2. **Routes → Edit routes → Add route**: destination `0.0.0.0/0`, target **Internet Gateway → `TodoApp-IGW`**.
3. **Subnet associations → Edit subnet associations**: select both public subnets.

![TodoApp-Public-Route-Table associated with Public-A (10.0.1.0/24) and Public-B (10.0.2.0/24)](images/r2-03-public-rt-associations.png)

**Private route table**

1. Create `TodoApp-Private-Route-Table` in `TodoAppVPC`.
2. Leave the routes as they are (only `10.0.0.0/16 → local`).
3. Associate both private subnets.

![TodoApp-Private-Route-Table associated with Private-A (10.0.3.0/24) and Private-B (10.0.4.0/24)](images/r2-04-private-rt-associations.png)

With no route to the internet, nothing outside the VPC can reach the database.

## 4. Check the VPC

Open `TodoAppVPC`. In **Details**, check:
- **IPv4 CIDR** is `10.0.0.0/16`
- **DNS resolution** and **DNS hostnames** are both **Enabled**

Then open the **Resource map** tab. It should show:
- the four subnets, each wired to the correct route table
- the public route table connected to `TodoApp-IGW`

The third route table (`rtb-...` with no name) is the VPC's main route table, which AWS creates automatically. No subnet uses it.

![TodoAppVPC details (10.0.0.0/16, DNS resolution and hostnames enabled) and resource map: public subnets to TodoApp-Public-Route-Table to TodoApp-IGW, private subnets to TodoApp-Private-Route-Table](images/r2-01-vpc-resource-map.png)

## 5. Create the security groups

Go to **VPC → Security → Security groups** (or **EC2 → Network & Security → Security Groups**) and choose **Create security group**. Create all three groups in `TodoAppVPC`, in this order, because each one refers to the one before it.

| Name | Inbound rule | Source |
|---|---|---|
| `ToDoApp-ALB-SG` | HTTP, port `80` | **Anywhere-IPv4** `0.0.0.0/0` |
| `ToDoApp-Webserver-SG` | Custom TCP, port `3000` | **Custom** → `ToDoApp-ALB-SG` |
| `ToDoApp-Webserver-SG` | SSH, port `22` | **My IP** |
| `ToDoApp-Database-SG` | MYSQL/Aurora, port `3306` | **Custom** → `ToDoApp-Webserver-SG` |

Leave the outbound rules at their default (all traffic).

Using security group IDs as sources means only the ALB can reach the app, and only the app instances can reach the database.

The SSH rule is optional. **My IP** fills in your current public IP as a `/32`, so only your machine can connect. Never use `0.0.0.0/0` for SSH. If your IP changes (new network, VPN), edit the rule and select **My IP** again. Without the SSH rule, use Session Manager instead.

Check each group's **Inbound rules** tab:

| Security group | ID | Inbound rules |
|---|---|---|
| `ToDoApp-ALB-SG` | `sg-0998932174b01d949` | HTTP `80` from `0.0.0.0/0` only |
| `ToDoApp-Webserver-SG` | `sg-0d06e3270610cb1c5` | Custom TCP `3000` from `ToDoApp-ALB-SG`, SSH `22` from My IP |
| `ToDoApp-Database-SG` | `sg-0c4a575327fbb8c10` | MYSQL/Aurora `3306` from `ToDoApp-Webserver-SG` |

**`ToDoApp-ALB-SG`**: a single rule, HTTP `80` from anywhere.

![ToDoApp-ALB-SG inbound rules: one rule, HTTP 80 from 0.0.0.0/0](images/r2-05-sg-alb.png)

**`ToDoApp-Webserver-SG`**: TCP `3000` from `ToDoApp-ALB-SG` (`sg-0998932174b01d949`), and SSH `22` from your IP only.

![ToDoApp-Webserver-SG inbound rules: Custom TCP 3000 from the ALB security group, SSH 22 from my IP /32](images/r2-06-sg-webserver.png)

> **Common mistake:** opening SSH, HTTP and MySQL on `ToDoApp-Webserver-SG` to `0.0.0.0/0`. Another is putting the SSH rule on `ToDoApp-ALB-SG` instead of the web server group. See [troubleshooting.md → Web server security group open to the internet](troubleshooting.md#web-server-security-group-open-to-the-internet) and [SSH rule on the wrong security group](troubleshooting.md#ssh-rule-on-the-wrong-security-group-run-2).

## Next step

[Launch the web servers (EC2)](setup-ec2.md).
