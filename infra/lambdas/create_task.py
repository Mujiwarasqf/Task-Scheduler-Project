import os, json, uuid, boto3
TABLE = os.environ["TABLE_NAME"]
ddb = boto3.resource("dynamodb").Table(TABLE)

def handler(event, context):
    body = json.loads(event.get("body") or "{}")
    title = body["title"]
    user_id = body.get("user_id","demo")
    due = body.get("due_date")
    task_id = str(uuid.uuid4())
    item = {"PK": user_id, "SK": task_id, "title": title, "done": False}
    if due:
        item["due_date"] = due
    ddb.put_item(Item=item)
    return {"statusCode":201, "headers":{"Content-Type":"application/json"},
            "body": json.dumps({"task_id":task_id})}