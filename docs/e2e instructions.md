## What This Project Does

`ai-zoomcamp-2026-hw3` is a small local task relay:

1. Agents register with the relay.
2. One agent sends text to another agent.
3. A worker claims the task.
4. The worker processes it locally.
5. The worker sends back a result.

The included worker only performs:

```python
input.upper()
```

It does not run submitted text as Python and does not use an LLM.

## Complete Example

Open three terminals.

### 1. Start the relay

```bash
cd ~/projects/ai-zoomcamp/ai-zoomcamp-2026-hw3

uv sync --dev
uv run uvicorn main:app --reload
```

The API is now available at:

```text
http://127.0.0.1:8000
```

Check it:

```bash
curl http://127.0.0.1:8000/health
```

Expected response:

```json
{"status":"ok"}
```

### 2. Register two agents

In a second terminal:

```bash
cd ~/projects/ai-zoomcamp/ai-zoomcamp-2026-hw3

ALICE_JSON=$(curl -sS -X POST http://127.0.0.1:8000/api/v1/agents \
  -H 'content-type: application/json' \
  -d '{"name":"alice","description":"Sends tasks"}')

BOB_JSON=$(curl -sS -X POST http://127.0.0.1:8000/api/v1/agents \
  -H 'content-type: application/json' \
  -d '{"name":"uppercase","description":"Uppercases text"}')

ALICE_ID=$(printf '%s' "$ALICE_JSON" | python -c 'import json,sys; print(json.load(sys.stdin)["agent_id"])')
ALICE_TOKEN=$(printf '%s' "$ALICE_JSON" | python -c 'import json,sys; print(json.load(sys.stdin)["token"])')

BOB_ID=$(printf '%s' "$BOB_JSON" | python -c 'import json,sys; print(json.load(sys.stdin)["agent_id"])')
BOB_TOKEN=$(printf '%s' "$BOB_JSON" | python -c 'import json,sys; print(json.load(sys.stdin)["token"])')

# Use these outputs to assign the variables in the rest of terminals:
echo "ALICE_ID=$ALICE_ID"
echo "ALICE_TOKEN=$ALICE_TOKEN"
echo "BOB_ID=$BOB_ID"
echo "BOB_TOKEN=$BOB_TOKEN"
```

Keep these shell variables available in this terminal.

### 3. Start the worker

In the same terminal:

```bash
uv run python main.py worker \
  --agent-id "$BOB_ID" \
  --token "$BOB_TOKEN" \
  --worker-id uppercase-worker \
  --stop-after 1
```

The worker will wait for one task. It will exit after completing it.

### 4. Send a task

In a third terminal, register variables again or use the values from the previous terminal:

```bash
cd ~/projects/ai-zoomcamp/ai-zoomcamp-2026-hw3

curl -sS -X POST http://127.0.0.1:8000/api/v1/tasks \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H 'content-type: application/json' \
  -H 'Idempotency-Key: greeting-1' \
  -d "{\"to\":\"$BOB_ID\",\"input\":\"Hello from Alice\"}"
```

Expected response:

```json
{
  "task_id": "task_...",
  "status": "queued"
}
```

The worker claims the task and completes it with:

```text
HELLO FROM ALICE
```

Save the returned task ID:

```bash
TASK_ID="task_..."
```

Then retrieve the result:

```bash
curl -sS \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  "http://127.0.0.1:8000/api/v1/tasks/$TASK_ID"
```

Expected result:

```json
{
  "task_id": "task_...",
  "from": "agent_...",
  "to": "agent_...",
  "input": "Hello from Alice",
  "status": "completed",
  "output": "HELLO FROM ALICE",
  "error": null,
  "attempt_count": 1
}
```

## Persist Worker Credentials

Instead of passing the token directly, let the worker register itself and save credentials:

```bash
uv run python main.py worker \
  --name uppercase \
  --credentials ./uppercase-credentials.json \
  --worker-id laptop-1
```

The credential file is created with restrictive permissions. On later runs:

```bash
uv run python main.py worker \
  --credentials ./uppercase-credentials.json \
  --worker-id laptop-1
```

Do not commit this file to source control.

## View the Dashboard

Open:

```text
http://127.0.0.1:8000/
```

Paste an agent token into the dashboard. It displays:

- Registered agents
- Sent and received tasks
- Task status
- Outputs and errors
- Delivery attempts

## Useful API Commands

List tasks sent by Alice:

```bash
curl -sS \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  "http://127.0.0.1:8000/api/v1/tasks?direction=sent"
```

List tasks received by Bob:

```bash
curl -sS \
  -H "Authorization: Bearer $BOB_TOKEN" \
  "http://127.0.0.1:8000/api/v1/tasks?direction=received"
```

View delivery attempts:

```bash
curl -sS \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  "http://127.0.0.1:8000/api/v1/tasks/$TASK_ID/attempts"
```

## Important Behavior

- The default database is `agent-relay.db`.
- Tasks remain queued if the recipient worker is offline.
- Claims expire after 60 seconds by default.
- Long-running workers send heartbeats automatically.
- Delivery is at least once, so a task can be executed again after a worker crashes.
- `Idempotency-Key` prevents accidental duplicate task creation.
- Tokens are shown only during registration.
- Run tests with:

```bash
uv run pytest -q
```

The current test suite passes: `4 passed`.