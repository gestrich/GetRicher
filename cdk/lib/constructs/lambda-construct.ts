import { Construct } from 'constructs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as sqs from 'aws-cdk-lib/aws-sqs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as sns from 'aws-cdk-lib/aws-sns';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import { Duration, RemovalPolicy } from 'aws-cdk-lib';
import * as path from 'path';

export interface LambdaConstructProps {
  queue: sqs.Queue;
  dataBucket: s3.Bucket;
  dynamoDbTable: dynamodb.Table;
  memorySize: number;
  timeout: number;
  reservedConcurrentExecutions?: number;
  snsPlatformArn?: string;
  pivotDay?: string;
  adminPasswordHash?: string;
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
        DYNAMODB_TABLE_NAME: props.dynamoDbTable.tableName,
        SNS_PLATFORM_ARN: props.snsPlatformArn ?? '',
        PIVOT_DAY: props.pivotDay ?? 'saturday',
        ADMIN_PASSWORD_HASH: props.adminPasswordHash ?? ''
      }
    });

    props.dataBucket.grantReadWrite(this.function);
    props.queue.grantSendMessages(this.function);
    props.dynamoDbTable.grantReadWriteData(this.function);

    // Grant read access to the LUNCH_MONEY_TOKEN secret (created manually outside CDK)
    const lunchMoneySecret = secretsmanager.Secret.fromSecretNameV2(this, 'LunchMoneySecret', 'LUNCH_MONEY_TOKEN');
    lunchMoneySecret.grantRead(this.function);

    this.function.configureAsyncInvoke({
      maxEventAge: Duration.minutes(30),
      retryAttempts: 1
    });

    // Grant SNS permissions for mobile push notifications
    this.function.addToRolePolicy(new iam.PolicyStatement({
      actions: [
        'sns:CreatePlatformEndpoint',
        'sns:Publish',
        'sns:ListEndpointsByPlatformApplication',
      ],
      resources: ['*'],
    }));

    // Grant CloudWatch Logs permissions for iOS OTLP proxy endpoint
    this.function.addToRolePolicy(new iam.PolicyStatement({
      actions: [
        'logs:PutLogEvents',
        'logs:CreateLogStream',
        'logs:DescribeLogStreams',
      ],
      resources: ['arn:aws:logs:*:*:log-group:/getricher/ios:*'],
    }));
    this.function.addToRolePolicy(new iam.PolicyStatement({
      actions: ['logs:CreateLogGroup'],
      resources: ['arn:aws:logs:*:*:log-group:/getricher/ios'],
    }));

    // Daily paydown report: every day at 5:00 AM UTC
    const dailyReportRule = new events.Rule(this, 'DailyReportRule', {
      schedule: events.Schedule.cron({ minute: '0', hour: '5' }),
      description: 'Daily paydown report and push notification',
      enabled: true
    });
    dailyReportRule.addTarget(new targets.LambdaFunction(this.function));
  }
}
