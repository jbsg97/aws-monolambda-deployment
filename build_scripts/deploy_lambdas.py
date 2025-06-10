import os
import hashlib
import boto3
import zipfile

from datetime import datetime
from zoneinfo import ZoneInfo

def get_environment_config():
    """Determine environment and S3 bucket based on environment variables"""
    # Get environment variables with defaults
    is_rollback = os.environ.get('IS_ROLLBACK', 'false').lower() == 'true'
    environment = os.environ.get('ENVIRONMENT', '')
    specific_lambdas = os.environ.get('SPECIFIC_LAMBDAS', '').split(',') if os.environ.get('SPECIFIC_LAMBDAS') else []
    
    # If not a rollback, determine environment from branch name
    if not is_rollback:
        branch_name = os.environ.get('BRANCH_NAME', '')
        print(f"Branch name: {branch_name}")
        
        if branch_name.startswith('feature/'):
            environment = 'dev'
        elif branch_name == 'qa':
            environment = 'qa'
        elif branch_name == 'main':
            environment = 'prod'
        else:
            environment = 'dev'

    # Environment mapping
    env_config = {
        'dev': os.environ['S3_BUCKET_DEV'].strip(),
        'qa': os.environ['S3_BUCKET_QA'].strip(),
        'prod': os.environ['S3_BUCKET_PROD'].strip()
    }
    
    s3_bucket = env_config[environment]
    print(f"Selected environment: {environment}")
    print(f"Using S3 bucket: {s3_bucket}")
    print(f"Is rollback: {is_rollback}")
    if specific_lambdas:
        print(f"Specific lambdas for rollback: {', '.join(specific_lambdas)}")
    
    return environment, s3_bucket, is_rollback, specific_lambdas

def get_previous_deployment(dynamodb_client, function_name, environment):
    """Get previous successful deployment for a function"""
    try:
        response = dynamodb_client.query(
            TableName='lambda-deployments',
            KeyConditionExpression='function_name = :fn AND environment = :env',
            ExpressionAttributeValues={
                ':fn': {'S': function_name},
                ':env': {'S': environment}
            },
            Limit=2,
            ScanIndexForward=False
        )
        deployments = response.get('Items', [])
        return deployments[1] if len(deployments) >= 2 else None
    except Exception as e:
        print(f"Error getting previous deployment: {e}")
        return None

def calculate_hash(directory):
    """Calculate hash of all files in directory"""
    sha256_hash = hashlib.sha256()
    
    for root, _, files in os.walk(directory):
        for file in sorted(files):
            file_path = os.path.join(root, file)
            with open(file_path, 'rb') as f:
                for chunk in iter(lambda: f.read(4096), b''):
                    sha256_hash.update(chunk)
    
    return sha256_hash.hexdigest()

def create_zip(source_dir, output_path):
    """Create ZIP file from directory"""
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(source_dir):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, source_dir)
                zipf.write(file_path, arcname)

def find_lambda_functions(base_dir='lambdas'):
    """Find all Lambda functions in domain-specific folders"""
    lambda_functions = []
    
    # Walk through all directories
    for root, dirs, files in os.walk(base_dir):
        # Look for Python files that might indicate a Lambda function
        if any(file.endswith('.py') for file in files):
            # Check if this is a Lambda function directory
            if any(file == 'lambda_function.py' for file in files) or \
               any('lambda' in dir.lower() for dir in dirs):
                lambda_functions.append(root)
    
    return lambda_functions

def main():
    # Get environment variables
    environment, s3_bucket, is_rollback, specific_lambdas = get_environment_config()
    commit_id = os.environ.get('COMMIT_SHA', 'unknown').strip()
    branch_name = os.environ.get('BRANCH_NAME', 'dev').strip()

    # Initialize AWS clients
    s3 = boto3.client('s3')
    dynamodb = boto3.client('dynamodb')
    lambda_client = boto3.client('lambda')

    # Process each lambda function
    for lambda_dir in find_lambda_functions():
        function_name = os.path.basename(lambda_dir)
        domain = os.path.basename(os.path.dirname(lambda_dir))
        
        print(f"Processing {function_name} from domain {domain} for {environment}")

        # Skip if not in specific lambdas list during rollback
        if is_rollback and specific_lambdas and function_name not in specific_lambdas:
            continue

        if is_rollback:
            previous_deployment = get_previous_deployment(dynamodb, function_name, environment)
            if previous_deployment:
                code_hash = previous_deployment['code_hash']['S']
                print(f"Rolling back {function_name} to hash {code_hash}")
            else:
                print(f"No previous deployment found for {function_name}")
                continue
        else:
            # Calculate hash of the lambda code
            code_hash = calculate_hash(lambda_dir)

            # Check existing deployment in DynamoDB
            try:
                response = dynamodb.query(
                    TableName='lambda-deployments',
                    IndexName='function_env_index',
                    KeyConditionExpression='function_name = :fn AND environment = :env',
                    ExpressionAttributeValues={
                        ':fn': {'S': function_name},
                        ':env': {'S': environment}
                    },
                    ProjectionExpression='code_hash'
                )
                
                items = response.get('Items', [])
                existing_hash = items[0].get('code_hash', {}).get('S', '') if items else ''
            except Exception as e:
                print(f"Warning: Could not get existing hash: {e}")
                existing_hash = ''

            if code_hash != existing_hash:
                print("New code detected, packaging and uploading...")
                
                # Create ZIP file
                zip_path = f"/tmp/{function_name}.zip"
                create_zip(lambda_dir, zip_path)

                # Upload to S3
                s3_key = f"{function_name}/{code_hash}/function.zip"
                s3.upload_file(zip_path, s3_bucket, s3_key)

                # Update Lambda function
                lambda_client.update_function_code(
                    FunctionName=f"{function_name}_{environment}",
                    S3Bucket=s3_bucket,
                    S3Key=s3_key
                )

                # Record deployment in DynamoDB
                deployment_id = f"{function_name}_{environment}_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"
                developer = os.environ.get('DEVELOPER').strip()
                local_time = datetime.now(ZoneInfo("America/Mexico_City"))
                dynamodb.put_item(
                    TableName='lambda-deployments',
                    Item={
                        'deployment_id': {'S': deployment_id},
                        'function_name': {'S': function_name},
                        'developer': {'S': developer},
                        'environment': {'S': environment},
                        'code_hash': {'S': code_hash},
                        'deployed_at': {'S': local_time},
                        'commit_id': {'S': commit_id},
                        'branch_name': {'S': branch_name}
                    }
                )

                # Cleanup
                os.remove(zip_path)
            else:
                print(f"No changes detected for {function_name}")

if __name__ == '__main__':
    main()