import os, json, boto3
from datetime import datetime, timezone
TABLE = os.environ["TABLE_NAME"]
TOPIC = os.environ["TOPIC_ARN"]
TZ = os.environ.get("TZ", "Europe/London")

ddb = boto3.resource("dynamodb").Table(TABLE)
sns = boto3.client("sns")

def handler(event, context):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    resp = ddb.scan(FilterExpression=boto3.dynamodb.conditions.Attr("due_date").begins_with(today) & 
                                    boto3.dynamodb.conditions.Attr("done").eq(False))
    
    due_tasks = resp["Items"]
    if due_tasks:
        message = f"You have {len(due_tasks)} task(s) due today:\n\n"
        for task in due_tasks:
            message += f"- {task['title']}\n"
        
        sns.publish(TopicArn=TOPIC, Subject="Tasks Due Today", Message=message)
        return {"statusCode":200, "body": json.dumps(f"Sent notification for {len(due_tasks)} tasks")}
    
    return {"statusCode":200, "body": json.dumps("No tasks due today")}