#!/usr/bin/env python3
"""
Lambda Deployment Script

This script automates the deployment of AWS Lambda functions.
It handles packaging, uploading to S3, updating Lambda functions,
and recording deployments in DynamoDB.
"""

import os
import sys
import hashlib
import boto3
import zipfile
import logging
import concurrent.futures
from typing import Dict, List, Tuple, Optional, Any
from datetime import datetime
from zoneinfo import ZoneInfo
from botocore.exceptions import ClientError

# Constants
LAMBDA_BASE_DIR = 'lambdas'
DEPLOYMENT_TABLE = 'lambda-deployments'
DEPLOYMENT_INDEX = 'function_env_index'
TEMP_DIR = '/tmp'
MAX_RETRIES = 3
RETRY_DELAY = 1  # seconds
MAX_WORKERS = 5  # for parallel processing

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('lambda-deployer')


class ConfigurationError(Exception):
    """Exception raised for configuration errors."""
    pass


class DeploymentError(Exception):
    """Exception raised for deployment errors."""
    pass


class LambdaDeployer:
    """Handles the deployment of AWS Lambda functions."""

    def __init__(self):
        """Initialize the deployer with AWS clients and configuration."""
        self.environment, self.s3_bucket, self.is_rollback, self.specific_lambdas = self._get_environment_config()
        self.commit_id = os.environ.get('COMMIT_SHA', 'unknown').strip()
        self.branch_name = os.environ.get('BRANCH_NAME', 'dev').strip()
        self.developer = os.environ.get('DEVELOPER', 'unknown').strip()
        
        # Initialize AWS clients with retry configuration
        self.s3 = self._create_aws_client('s3')
        self.dynamodb = self._create_aws_client('dynamodb')
        self.lambda_client = self._create_aws_client('lambda')
        
        # Validate S3 bucket exists
        self._validate_s3_bucket()

    def _create_aws_client(self, service_name: str) -> Any:
        """Create an AWS client with retry configuration."""
        try:
            return boto3.client(
                service_name,
                config=boto3.config.Config(
                    retries={'max_attempts': MAX_RETRIES, 'mode': 'standard'}
                )
            )
        except Exception as e:
            logger.error(f"Failed to create AWS {service_name} client: {e}")
            raise DeploymentError(f"AWS client initialization failed: {e}")

    def _validate_s3_bucket(self) -> None:
        """Validate that the S3 bucket exists and is accessible."""
        try:
            self.s3.head_bucket(Bucket=self.s3_bucket)
            logger.info(f"S3 bucket validation successful: {self.s3_bucket}")
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            if error_code == '404':
                raise ConfigurationError(f"S3 bucket does not exist: {self.s3_bucket}")
            elif error_code == '403':
                raise ConfigurationError(f"No permission to access S3 bucket: {self.s3_bucket}")
            else:
                raise ConfigurationError(f"S3 bucket validation failed: {e}")

    def _get_environment_config(self) -> Tuple[str, str, bool, List[str]]:
        """
        Determine environment and S3 bucket based on environment variables.
        
        Returns:
            Tuple containing environment name, S3 bucket name, rollback flag, and specific lambdas list
        
        Raises:
            ConfigurationError: If required environment variables are missing
        """
        # Get environment variables with defaults
        is_rollback = os.environ.get('IS_ROLLBACK', 'false').lower() == 'true'
        environment = os.environ.get('ENVIRONMENT', '')
        specific_lambdas = os.environ.get('SPECIFIC_LAMBDAS', '').split(',') if os.environ.get('SPECIFIC_LAMBDAS') else []
        
        # If not a rollback, determine environment from branch name
        if not is_rollback:
            branch_name = os.environ.get('BRANCH_NAME', '')
            logger.info(f"Branch name: {branch_name}")
            
            if branch_name.startswith('feature/'):
                environment = 'dev'
            elif branch_name == 'qa':
                environment = 'qa'
            elif branch_name == 'main':
                environment = 'prod'
            else:
                environment = 'dev'

        # Validate required environment variables
        required_vars = [f'S3_BUCKET_{environment.upper()}']
        missing_vars = [var for var in required_vars if var not in os.environ]
        if missing_vars:
            raise ConfigurationError(f"Missing required environment variables: {', '.join(missing_vars)}")

        # Environment mapping
        env_config = {
            'dev': os.environ.get('S3_BUCKET_DEV', '').strip(),
            'qa': os.environ.get('S3_BUCKET_QA', '').strip(),
            'prod': os.environ.get('S3_BUCKET_PROD', '').strip()
        }
        
        # Validate environment
        if environment not in env_config:
            raise ConfigurationError(f"Invalid environment: {environment}")
        
        s3_bucket = env_config[environment]
        if not s3_bucket:
            raise ConfigurationError(f"S3 bucket not configured for environment: {environment}")
        
        logger.info(f"Selected environment: {environment}")
        logger.info(f"Using S3 bucket: {s3_bucket}")
        logger.info(f"Is rollback: {is_rollback}")
        if specific_lambdas:
            logger.info(f"Specific lambdas for rollback: {', '.join(specific_lambdas)}")
        
        return environment, s3_bucket, is_rollback, specific_lambdas

    def get_previous_deployment(self, function_name: str, environment: str) -> Optional[Dict[str, Any]]:
        """
        Get previous successful deployment for a function.
        
        Args:
            function_name: Name of the Lambda function
            environment: Deployment environment
            
        Returns:
            Previous deployment record or None if not found
        """
        try:
            response = self.dynamodb.query(
                TableName=DEPLOYMENT_TABLE,
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
        except ClientError as e:
            logger.error(f"Error getting previous deployment for {function_name}: {e}")
            return None

    def calculate_hash(self, directory: str) -> str:
        """
        Calculate hash of all files in directory.
        
        Args:
            directory: Path to the directory
            
        Returns:
            SHA-256 hash of the directory contents
        """
        if not os.path.exists(directory):
            raise DeploymentError(f"Directory does not exist: {directory}")
            
        sha256_hash = hashlib.sha256()
        
        try:
            for root, _, files in os.walk(directory):
                for file in sorted(files):
                    file_path = os.path.join(root, file)
                    with open(file_path, 'rb') as f:
                        for chunk in iter(lambda: f.read(4096), b''):
                            sha256_hash.update(chunk)
        except IOError as e:
            logger.error(f"Error reading files for hash calculation: {e}")
            raise DeploymentError(f"Hash calculation failed: {e}")
        
        return sha256_hash.hexdigest()

    def create_zip(self, source_dir: str, output_path: str) -> None:
        """
        Create ZIP file from directory.
        
        Args:
            source_dir: Source directory to zip
            output_path: Path for the output ZIP file
        """
        try:
            with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                for root, _, files in os.walk(source_dir):
                    for file in files:
                        file_path = os.path.join(root, file)
                        arcname = os.path.relpath(file_path, source_dir)
                        zipf.write(file_path, arcname)
            
            # Verify the zip file was created successfully
            if not os.path.exists(output_path):
                raise DeploymentError(f"Failed to create ZIP file: {output_path}")
                
            logger.debug(f"Created ZIP file: {output_path}")
        except (IOError, zipfile.BadZipFile) as e:
            logger.error(f"Error creating ZIP file: {e}")
            raise DeploymentError(f"ZIP creation failed: {e}")

    def find_lambda_functions(self, base_dir: str = LAMBDA_BASE_DIR) -> List[str]:
        """
        Find all Lambda functions in domain-specific folders.
        
        Args:
            base_dir: Base directory to search for Lambda functions
            
        Returns:
            List of Lambda function directories
        """
        if not os.path.exists(base_dir):
            logger.warning(f"Lambda base directory does not exist: {base_dir}")
            return []
            
        lambda_functions = []
        
        # Walk through all directories
        for root, _, files in os.walk(base_dir):
            # Check if this is a Lambda function directory (contains lambda_function.py)
            if 'lambda_function.py' in files:
                lambda_functions.append(root)
        
        logger.info(f"Found {len(lambda_functions)} Lambda functions")
        return lambda_functions

    def upload_to_s3(self, local_path: str, s3_key: str) -> bool:
        """
        Upload a file to S3.
        
        Args:
            local_path: Local file path
            s3_key: S3 object key
            
        Returns:
            True if successful, False otherwise
        """
        try:
            self.s3.upload_file(local_path, self.s3_bucket, s3_key)
            logger.info(f"Uploaded {local_path} to s3://{self.s3_bucket}/{s3_key}")
            return True
        except ClientError as e:
            logger.error(f"Error uploading to S3: {e}")
            return False

    def update_lambda_function(self, function_name: str, s3_key: str) -> bool:
        """
        Update Lambda function code.
        
        Args:
            function_name: Name of the Lambda function
            s3_key: S3 object key for the function code
            
        Returns:
            True if successful, False otherwise
        """
        try:
            lambda_name = f"{function_name}_{self.environment}"
            self.lambda_client.update_function_code(
                FunctionName=lambda_name,
                S3Bucket=self.s3_bucket,
                S3Key=s3_key
            )
            logger.info(f"Updated Lambda function: {lambda_name}")
            return True
        except ClientError as e:
            logger.error(f"Error updating Lambda function: {e}")
            return False

    def record_deployment(self, function_name: str, code_hash: str) -> bool:
        """
        Record deployment in DynamoDB.
        
        Args:
            function_name: Name of the Lambda function
            code_hash: Hash of the function code
            
        Returns:
            True if successful, False otherwise
        """
        try:
            deployment_id = f"{function_name}_{self.environment}_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"
            local_time = datetime.now(ZoneInfo("America/Mexico_City"))
            formatted_time = local_time.strftime('%b %d, %Y %I:%M %p')
            
            self.dynamodb.put_item(
                TableName=DEPLOYMENT_TABLE,
                Item={
                    'deployment_id': {'S': deployment_id},
                    'function_name': {'S': function_name},
                    'developer': {'S': self.developer},
                    'environment': {'S': self.environment},
                    'code_hash': {'S': code_hash},
                    'deployed_at': {'S': formatted_time},
                    'commit_id': {'S': self.commit_id},
                    'branch_name': {'S': self.branch_name}
                }
            )
            logger.info(f"Recorded deployment: {deployment_id}")
            return True
        except ClientError as e:
            logger.error(f"Error recording deployment: {e}")
            return False

    def get_existing_hash(self, function_name: str) -> str:
        """
        Get existing code hash from DynamoDB.
        
        Args:
            function_name: Name of the Lambda function
            
        Returns:
            Existing code hash or empty string if not found
        """
        try:
            response = self.dynamodb.query(
                TableName=DEPLOYMENT_TABLE,
                IndexName=DEPLOYMENT_INDEX,
                KeyConditionExpression='function_name = :fn AND environment = :env',
                ExpressionAttributeValues={
                    ':fn': {'S': function_name},
                    ':env': {'S': self.environment}
                },
                ProjectionExpression='code_hash',
                Limit=1,
                ScanIndexForward=False
            )
            
            items = response.get('Items', [])
            return items[0].get('code_hash', {}).get('S', '') if items else ''
        except ClientError as e:
            logger.warning(f"Could not get existing hash for {function_name}: {e}")
            return ''

    def process_lambda(self, lambda_dir: str) -> bool:
        """
        Process a single Lambda function.
        
        Args:
            lambda_dir: Directory containing the Lambda function
            
        Returns:
            True if successful, False otherwise
        """
        function_name = os.path.basename(lambda_dir)
        domain = os.path.basename(os.path.dirname(lambda_dir))
        
        logger.info(f"Processing {function_name} from domain {domain} for {self.environment}")

        # Skip if not in specific lambdas list during rollback
        if self.is_rollback and self.specific_lambdas and function_name not in self.specific_lambdas:
            logger.info(f"Skipping {function_name} (not in specific lambdas list)")
            return True

        try:
            if self.is_rollback:
                previous_deployment = self.get_previous_deployment(function_name, self.environment)
                if previous_deployment:
                    code_hash = previous_deployment['code_hash']['S']
                    logger.info(f"Rolling back {function_name} to hash {code_hash}")
                    
                    # Update Lambda function with previous code
                    s3_key = f"{function_name}/{code_hash}/function.zip"
                    return self.update_lambda_function(function_name, s3_key)
                else:
                    logger.warning(f"No previous deployment found for {function_name}")
                    return False
            else:
                # Calculate hash of the lambda code
                code_hash = self.calculate_hash(lambda_dir)
                
                # Check existing deployment in DynamoDB
                existing_hash = self.get_existing_hash(function_name)
                
                if code_hash != existing_hash:
                    logger.info(f"New code detected for {function_name}, packaging and uploading...")
                    
                    # Create ZIP file
                    zip_path = os.path.join(TEMP_DIR, f"{function_name}.zip")
                    self.create_zip(lambda_dir, zip_path)
                    
                    # Upload to S3
                    s3_key = f"{function_name}/{code_hash}/function.zip"
                    if not self.upload_to_s3(zip_path, s3_key):
                        return False
                    
                    # Update Lambda function
                    if not self.update_lambda_function(function_name, s3_key):
                        return False
                    
                    # Record deployment in DynamoDB
                    if not self.record_deployment(function_name, code_hash):
                        return False
                    
                    # Cleanup
                    try:
                        os.remove(zip_path)
                    except OSError as e:
                        logger.warning(f"Failed to remove temporary file {zip_path}: {e}")
                    
                    return True
                else:
                    logger.info(f"No changes detected for {function_name}")
                    return True
        except Exception as e:
            logger.error(f"Error processing {function_name}: {e}")
            return False

    def deploy_all(self) -> None:
        """Deploy all Lambda functions."""
        lambda_functions = self.find_lambda_functions()
        
        if not lambda_functions:
            logger.warning("No Lambda functions found")
            return
        
        # Process Lambda functions in parallel
        success_count = 0
        failure_count = 0
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            future_to_lambda = {executor.submit(self.process_lambda, lambda_dir): lambda_dir for lambda_dir in lambda_functions}
            
            for future in concurrent.futures.as_completed(future_to_lambda):
                lambda_dir = future_to_lambda[future]
                function_name = os.path.basename(lambda_dir)
                
                try:
                    if future.result():
                        success_count += 1
                    else:
                        failure_count += 1
                except Exception as e:
                    logger.error(f"Exception processing {function_name}: {e}")
                    failure_count += 1
        
        logger.info(f"Deployment complete: {success_count} succeeded, {failure_count} failed")
        
        if failure_count > 0:
            logger.warning("Some deployments failed, check logs for details")


def main():
    """Main entry point for the script."""
    try:
        # Set log level from environment variable
        log_level = os.environ.get('LOG_LEVEL', 'INFO').upper()
        logger.setLevel(getattr(logging, log_level, logging.INFO))
        
        # Check for dry run mode
        dry_run = os.environ.get('DRY_RUN', 'false').lower() == 'true'
        if dry_run:
            logger.info("Running in DRY RUN mode - no changes will be made")
            # TODO: Implement dry run functionality
            
        # Deploy Lambda functions
        deployer = LambdaDeployer()
        deployer.deploy_all()
        
    except ConfigurationError as e:
        logger.error(f"Configuration error: {e}")
        sys.exit(1)
    except DeploymentError as e:
        logger.error(f"Deployment error: {e}")
        sys.exit(2)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(3)


if __name__ == '__main__':
    main()
