import { Stack, StackProps, Tags, CfnOutput, Duration } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { GetRicherConfig } from './config/types';
import { StorageConstruct } from './constructs/storage-construct';
import { QueueConstruct } from './constructs/queue-construct';
import { DynamoDBConstruct } from './constructs/dynamodb-construct';
import { LambdaConstruct } from './constructs/lambda-construct';
import { ApiGatewayConstruct } from './constructs/api-gateway-construct';
import { MonitoringConstruct } from './constructs/monitoring-construct';

export interface GetRicherStackProps extends StackProps {
  config: GetRicherConfig;
}

export class GetRicherStack extends Stack {
  constructor(scope: Construct, id: string, props: GetRicherStackProps) {
    super(scope, id, props);

    const { config } = props;

    const storage = new StorageConstruct(this, 'Storage');

    const queue = new QueueConstruct(this, 'Queue', {
      visibilityTimeout: Duration.seconds(4500),
      messageRetention: Duration.days(1),
      maxReceiveCount: 5
    });

    const dynamoDb = new DynamoDBConstruct(this, 'DynamoDB');

    const lambdaFunc = new LambdaConstruct(this, 'Lambda', {
      queue: queue.queue,
      dataBucket: storage.dataBucket,
      dynamoDbTable: dynamoDb.table,
      memorySize: config.lambda.memorySize,
      timeout: config.lambda.timeout,
      reservedConcurrentExecutions: config.lambda.reservedConcurrentExecutions
    });

    const apiGateway = new ApiGatewayConstruct(this, 'ApiGateway', {
      lambdaFunction: lambdaFunc.function
    });

    new MonitoringConstruct(this, 'Monitoring', {
      lambdaFunction: lambdaFunc.function,
      scheduleExpression: config.monitoring.scheduleExpression,
      appName: 'GetRicher',
      releaseLookbackHours: config.monitoring.releaseLookbackHours
    });

    Tags.of(this).add('Environment', config.environment);
    Tags.of(this).add('Application', 'get-richer');

    new CfnOutput(this, 'BucketName', {
      value: storage.dataBucket.bucketName,
      description: 'S3 Data Bucket Name'
    });
    new CfnOutput(this, 'QueueUrl', {
      value: queue.queue.queueUrl,
      description: 'SQS Queue URL'
    });
    new CfnOutput(this, 'DLQUrl', {
      value: queue.deadLetterQueue.queueUrl,
      description: 'Dead Letter Queue URL'
    });
    new CfnOutput(this, 'DynamoDBTableName', {
      value: dynamoDb.table.tableName,
      description: 'DynamoDB Table Name'
    });
    new CfnOutput(this, 'LambdaFunctionName', {
      value: lambdaFunc.function.functionName,
      description: 'Lambda Function Name'
    });
    new CfnOutput(this, 'ApiGatewayUrl', {
      value: apiGateway.api.url,
      description: 'API Gateway URL'
    });
  }
}
