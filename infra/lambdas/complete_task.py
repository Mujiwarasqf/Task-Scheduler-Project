import os, json, boto3
TABLE = os.environ["TABLE_NAME"]
ddb = boto3.resource("dynamodb").Table(TABLE)

def handler(event, context):
    task_id = event["pathParameters"]["task_id"]
    user_id = event["queryStringParameters"].get("user_id", "demo")
    ddb.update_item(
        Key={"PK": user_id, "SK": task_id},
        UpdateExpression="SET done = :val",
        ExpressionAttributeValues={":val": True}
    )
    return {"statusCode":200, "headers":{"Content-Type":"application/json"},
            "body": json.dumps({"message":"Task completed"})}