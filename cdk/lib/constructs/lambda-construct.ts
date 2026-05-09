import { Construct } from 'constructs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as sqs from 'aws-cdk-lib/aws-sqs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import { Duration, RemovalPolicy } from 'aws-cdk-lib';
import * as path from 'path';

export interface LambdaConstructProps {
  queue: sqs.Queue;
  dataBucket: s3.Bucket;
  dynamoDbTable: dynamodb.Table;
  memorySize: number;
  timeout: number;
  reservedConcurrentExecutions?: number;
}

export class LambdaConstruct extends Construct {
  public readonly function: lambda.Function;

  constructor(scope: Construct, id: string, props: LambdaConstructProps) {
    super(scope, id);

    const logGroup = new logs.LogGroup(this, 'LogGroup', {
      logGroupName: '/aws/lambda/get-richer',
      retention: logs.RetentionDays.TWO_WEEKS,
      removalPolicy: RemovalPolicy.DESTROY
    });

    this.function = new lambda.Function(this, 'Function', {
      functionName: 'get-richer',
      runtime: lambda.Runtime.PROVIDED_AL2,
      handler: 'lambda_function.main',
      code: lambda.Code.fromAsset(path.join(__dirname, '../../..', 'lambda.zip')),
      memorySize: props.memorySize,
      timeout: Duration.seconds(props.timeout),
      reservedConcurrentExecutions: props.reservedConcurrentExecutions,
      logGroup: logGroup,
      environment: {
        SQS_URL: props.queue.queueUrl,
        S3_BUCKET_NAME: props.dataBucket.bucketName,
        DYNAMODB_TABLE_NAME: props.dynamoDbTable.tableName
      }
    });

    props.dataBucket.grantReadWrite(this.function);
    props.queue.grantSendMessages(this.function);
    props.dynamoDbTable.grantReadWriteData(this.function);

    // Grant Secrets Manager read access for any secrets this Lambda may need
    const secretsPolicy = new secretsmanager.Secret(this, 'PlaceholderSecret', {
      secretName: 'get-richer/placeholder',
      removalPolicy: RemovalPolicy.DESTROY
    });
    secretsPolicy.grantRead(this.function);

    this.function.configureAsyncInvoke({
      maxEventAge: Duration.minutes(30),
      retryAttempts: 1
    });
  }
}
