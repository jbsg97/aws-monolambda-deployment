import boto3
import os
import json

def lambda_handler(event, context):
    lambda_client = boto3.client('lambda')
    
    # Get current feature/stage and environment
    feature = os.environ.get('FEATURE_NAME', '')
    env = os.environ.get('ENVIRONMENT', '')
    
    # If in feature branch, use feature alias
    qualifier = f"feature-{feature}" if feature else None
    
    invoke_args = {
        'FunctionName': f'lambda-b_{env}',
        'InvocationType': 'RequestResponse',
        'Payload': json.dumps(event)
    }

    if qualifier:
        invoke_args['Qualifier'] = qualifier

    response = lambda_client.invoke(**invoke_args)
    return {
        'statusCode': 200,
        'body': f'Testing lambda-b_{env} response',
        'lambda_response': json.loads(response['Payload'].read())
    }
