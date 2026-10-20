import json
import os
import time
import boto3

ssm = boto3.client("ssm")
sns = boto3.client("sns")

INSTANCE_ID = os.environ["INSTANCE_ID"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
ALLOWED_COMMAND = "bash /opt/ai-cloud-operations-center/restart-nginx.sh"


def notify(subject, message):
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject[:100],
        Message=message,
    )


def lambda_handler(event, context):
    # Only process CloudWatch alarm messages received through SNS.
    records = event.get("Records", [])
    if not records:
        raise ValueError("Expected an SNS-triggered event.")

    results = []

    for record in records:
        if record.get("EventSource") != "aws:sns":
            raise ValueError("Unexpected event source.")

        message = json.loads(record["Sns"]["Message"])
        alarm_name = message.get("AlarmName", "unknown-alarm")
        new_state = message.get("NewStateValue", "UNKNOWN")

        if new_state != "ALARM":
            results.append({"alarm": alarm_name, "action": "skipped"})
            continue

        response = ssm.send_command(
            InstanceIds=[INSTANCE_ID],
            DocumentName="AWS-RunShellScript",
            Parameters={"commands": [ALLOWED_COMMAND]},
            TimeoutSeconds=60,
            Comment="AI Cloud Operations Center: controlled Nginx recovery",
        )

        command_id = response["Command"]["CommandId"]
        deadline = time.time() + 90
        status = "Pending"

        while time.time() < deadline:
            try:
                invocation = ssm.get_command_invocation(
                    CommandId=command_id,
                    InstanceId=INSTANCE_ID,
                )
                status = invocation["Status"]
                if status in ("Success", "Cancelled", "TimedOut", "Failed"):
                    break
            except ssm.exceptions.InvocationDoesNotExist:
                pass
            time.sleep(3)

        notify(
            f"COC remediation: {status}",
            f"Alarm: {alarm_name}\nInstance: {INSTANCE_ID}\n"
            f"SSM command: {command_id}\nStatus: {status}",
        )

        results.append({
            "alarm": alarm_name,
            "command_id": command_id,
            "status": status,
        })

    return {"results": results}
