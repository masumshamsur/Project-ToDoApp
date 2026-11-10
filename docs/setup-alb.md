# Set up the Application Load Balancer

The ALB is the only public entry point. It listens on port `80` and forwards requests to port `3000` on the healthy instances. Both instances use the same RDS database, so it doesn't matter which one answers.

If something doesn't match, see [troubleshooting.md](troubleshooting.md).

## 1. Create the target group

1. In the **EC2** console, go to **Load Balancing → Target Groups → Create target group**.
2. Use these settings:

   | Setting | Value |
   |---|---|
   | Target type | Instances |
   | Name | `TodoApp-TG` |
   | Protocol : Port | HTTP : `3000` |
   | IP address type | IPv4 |
   | VPC | `TodoAppVPC` (**not** the default VPC) |
   | Protocol version | HTTP1 |
   | Health check path | `/` |
   | Advanced health check settings | Healthy / unhealthy threshold `2`, interval `10` s, success codes `200` (faster failover for testing) |

3. Choose **Next**, select `web-server-1` and `web-server-2`, keep port `3000`, choose **Include as pending below**, then **Create target group**.

The **Register targets** page only lists running instances in the target group's VPC. If it shows **No instances**, refresh the page first. That was the fix in Run 2. Otherwise see [troubleshooting.md → Register targets lists no instances](troubleshooting.md#register-targets-lists-no-instances-run-2).

Both targets show **Unused** until a load balancer uses the target group. That's expected.

![TodoApp-TG in TodoAppVPC with web-server-1 and web-server-2 registered on port 3000, health status Unused before the ALB exists](images/r2-37-tg-registered-unused.png)

> **Port shown as HTTP:80?** In Run 2 the group's **Protocol : Port** was left at `80`, while both targets were registered on `3000`. That still works: the group's port is only the default for new targets, and traffic and health checks use each target's own port (**Traffic port**). Setting it to `3000` avoids the confusion.

## 2. Create the load balancer

1. Go to **Load Balancing → Load Balancers → Create load balancer**, then choose **Create** under **Application Load Balancer**.
2. Use these settings:

   | Setting | Value |
   |---|---|
   | Name | `TodoApp-ALB` |
   | Scheme | Internet-facing |
   | IP address type | IPv4 |
   | VPC | `TodoAppVPC` |
   | Mappings | `us-east-1a` → `TodoApp-Subnet-Public-A`, `us-east-1b` → `TodoApp-Subnet-Public-B` (public subnets only) |
   | Security group | `ToDoApp-ALB-SG` (remove `default`) |
   | Listener | HTTP `80` → forward to `TodoApp-TG` |

3. Choose **Create load balancer**. The status starts as **Provisioning**.

4. Check for a **⚠ Reachability may be impacted** warning next to the name. It means `ToDoApp-ALB-SG` is missing an inbound or outbound rule. In Run 2 the group had **no outbound rule**, so the ALB couldn't reach the targets:

   ![TodoApp-ALB while Provisioning, with the Reachability may be impacted tooltip](images/r2-24-alb-reachability-warning.png)

   Fix it before going on: add an outbound rule **Custom TCP `3000` → `ToDoApp-Webserver-SG`** to `ToDoApp-ALB-SG`. See [troubleshooting.md → ALB "Reachability may be impacted"](troubleshooting.md#alb-reachability-may-be-impacted-no-outbound-rule-run-2), and [setup-network.md → How the rules fit together](setup-network.md#how-the-rules-fit-together) for why each rule exists.

   ![ToDoApp-ALB-SG outbound rules: one rule, Custom TCP 3000 to sg-0d06e3270610cb1c5 (ToDoApp-Webserver-SG)](images/r2-33-alb-sg-outbound-saved.png)

5. After 3–5 minutes the status becomes **Active** and the warning is gone. Check:
   - **Scheme:** Internet-facing, in `TodoAppVPC`
   - **Availability Zones:** `subnet-0eb1b1011dc3ba466` (Public-A, us-east-1a) and `subnet-0857da153503e6493` (Public-B, us-east-1b)
   - **Listener:** `HTTP:80` → forward to `TodoApp-TG` (100%)

   Copy the **DNS name**: `TodoApp-ALB-1357293675.us-east-1.elb.amazonaws.com`.

   ![TodoApp-ALB Active in the two public subnets, with the DNS name and the HTTP:80 listener forwarding to TodoApp-TG](images/r2-27-alb-active.png)

> **Cost:** an ALB is billed hourly (about $16–20/month in us-east-1) and usually isn't free tier. Delete it when you're done. See [teardown.md](teardown.md).

## 3. Point the app at the ALB

On **both** instances (over SSH or Session Manager, as `ec2-user`):

```bash
cd ~/todo-app
sed -i 's|^API_BASE_URL=.*|API_BASE_URL=http://TodoApp-ALB-1357293675.us-east-1.elb.amazonaws.com|' .env
grep API_BASE_URL .env
sudo systemctl restart todo-app
sleep 2; curl -s localhost:3000/config; echo
```

Use your own DNS name. The last command should print `{"API_BASE_URL":"http://TodoApp-ALB-1357293675.us-east-1.elb.amazonaws.com"}`. Without the `sleep`, `curl` can run before the app is listening again and print nothing.

**web-server-1:**

![web-server-1: API_BASE_URL set to the ALB DNS name in .env, and /config returning it after the restart](images/r2-28-api-base-url-ws1.png)

**web-server-2:**

![web-server-2: API_BASE_URL set to the ALB DNS name in .env, and /config returning it after the restart](images/r2-29-api-base-url-ws2.png)

The frontend reads `API_BASE_URL` from `/config` and sends all API calls there. The app only reads `.env` at startup, so always restart the service after editing it. If you skip this, the page loads through the ALB but shows an empty list and **Add Task** does nothing, because the browser calls `localhost:3000` on your own machine. See [troubleshooting.md → Page loads but the list is empty and Add Task does nothing](troubleshooting.md#page-loads-but-the-list-is-empty-and-add-task-does-nothing).

Check from your own machine. Both targets should return the ALB URL, so run it a few times:

```bash
for i in 1 2 3 4; do curl -s http://TodoApp-ALB-1357293675.us-east-1.elb.amazonaws.com/config; echo; done
```

## 4. Test it

1. In **Target Groups → TodoApp-TG → Targets**, wait until both instances are **Healthy**, one in each AZ.

   ![TodoApp-TG: 2 Healthy, 0 Unhealthy; web-server-2 in us-east-1b and web-server-1 in us-east-1a, both Healthy on port 3000](images/r2-32-tg-both-healthy.png)

   The ALB's **Resource map** tab shows the whole path: listener `HTTP:80` → default rule → `TodoApp-TG` → both instances on port `3000`, **Healthy**.

   ![TodoApp-ALB resource map: HTTP:80 listener, default forward rule, TodoApp-TG with 2 healthy targets, both instances Healthy on port 3000](images/r2-31-alb-resource-map-healthy.png)

2. Open `http://TodoApp-ALB-1357293675.us-east-1.elb.amazonaws.com` in a browser. Use `http://`: there's no HTTPS listener, so the browser shows **Not Secure**. Hard-refresh with **Cmd+Shift+R** (macOS) or **Ctrl+Shift+R**.

   The two tasks created on the servers in [setup-ec2.md](setup-ec2.md#38-test-on-the-instance) appear, which shows the ALB, both web servers and the shared database working together.

   ![The To-Do app through the ALB DNS name, listing Test from web-server-1 and Test from web-server-2](images/r2-30-app-via-alb.png)

3. Add a task, mark one complete (✔) and delete one (🗑). Here **Test via ALB** was added and marked complete (green, struck through):

   ![The app through the ALB with Test via ALB added and marked complete](images/r2-34-app-crud-via-alb.png)

   The due dates show one day early (`12/30/2026` for `2026-12-31`). That's a display bug in the app, not the infrastructure. See [troubleshooting.md → Due dates show one day early](troubleshooting.md#due-dates-show-one-day-early).

4. Test the API directly:

   ```bash
   curl http://TodoApp-ALB-1357293675.us-east-1.elb.amazonaws.com/tasks
   ```

## 5. Test high availability

Stop the **app** rather than the instance. Stopping the instance gives it a new public IP when it starts again.

1. On `web-server-1`:

   ```bash
   sudo systemctl stop todo-app
   ```

2. Within about 20 seconds (two failed checks, 10 seconds apart), **Targets** shows `web-server-1` as **Unhealthy** and `web-server-2` as **Healthy**. With the **Health status = healthy** filter, only `web-server-2` is left:

   ![TodoApp-TG during the failover test: 1 Healthy, 1 Unhealthy; filtered to healthy targets, only web-server-2 in us-east-1b remains](images/r2-35-failover-ws1-unhealthy.png)

3. Refresh the app and add a task. It still works and the existing tasks are still there, because the ALB sends traffic only to `web-server-2` and both instances share the same RDS database. Here **Added while server 1 down** was created while `web-server-1` was out:

   ![The app through the ALB while web-server-1 is down: Added while server 1 down was created successfully](images/r2-36-failover-task-added.png)

4. Start the app again. After about 20 seconds both targets are **Healthy** again.

   ```bash
   sudo systemctl start todo-app
   ```

   ![TodoApp-TG after restarting the app on web-server-1: 2 Healthy, 0 Unhealthy, both web servers Healthy again](images/r2-39-failover-recovered.png)

## Next steps (optional)

- Add an **HTTPS** listener on `443` with an ACM certificate, and redirect `80` to `443`.
- Replace the two instances with an **Auto Scaling group** that uses a launch template.
- Move the instances to private subnets with a NAT Gateway, so only the ALB is public.
- Store the database password in **Secrets Manager** instead of `.env`.

## Next step

When you're finished with the lab, [delete all the resources](teardown.md).
