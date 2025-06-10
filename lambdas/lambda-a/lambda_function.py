import boto3
import os
import json

def lambda_handler(event, context):
    lambda_client = boto3.client('lambda')
    
    # Get current feature/stage from environment
    feature = os.environ.get('FEATURE_NAME', '')
    
    # If in feature branch, use feature alias
    qualifier = f"feature-{feature}" if feature else None
    
    response = lambda_client.invoke(
        FunctionName='lambda-b',
        Qualifier=qualifier,  # Will use $LATEST if None
        InvocationType='RequestResponse',
        Payload=json.dumps(event)
    )
    return {
        'statusCode': 200,
        'body': 'Testing lambda-b response',
        'lambda_response': json.loads(response['Payload'].read())
    }
