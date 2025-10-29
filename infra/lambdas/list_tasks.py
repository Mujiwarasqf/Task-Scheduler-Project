import os, json, boto3
TABLE = os.environ["TABLE_NAME"]
ddb = boto3.resource("dynamodb").Table(TABLE)

def handler(event, context):
    user_id = event["queryStringParameters"].get("user_id", "demo")
    resp = ddb.query(KeyConditionExpression=boto3.dynamodb.conditions.Key("PK").eq(user_id))
    tasks = resp["Items"]
    return {"statusCode":200, "headers":{"Content-Type":"application/json"},
            "body": json.dumps(tasks, default=str)}